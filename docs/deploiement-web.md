# Mise en production web (Vercel)

L'app est construite par GitHub Actions (`.github/workflows/web.yml`) puis
envoyée à Vercel déjà compilée : Vercel n'a pas Flutter dans son
environnement de build. Chaque PR obtient une URL d'aperçu, chaque push sur
`main` part en production.

Le `vercel.json` à la racine désactive les déploiements automatiques de
l'intégration Git de Vercel, qui échoueraient faute de Flutter.

## 1. Créer le projet Vercel (une fois)

```bash
npx vercel@63.1.2 login
```

```bash
npx vercel@63.1.2 link
```

`link` crée le projet (nom proposé : `snack-runner`) et écrit
`.vercel/project.json`, non versionné. Y relever `orgId` et `projectId`.

L'URL de production sera `https://<nom-du-projet>.vercel.app`.

Créer ensuite un token : Vercel → Account Settings → Tokens.

## 2. Configurer GitHub (Settings → Secrets and variables → Actions)

| Type | Nom | Valeur |
|------|-----|--------|
| Secret | `VERCEL_TOKEN` | le token Vercel |
| Variable | `VERCEL_ORG_ID` | `orgId` de `.vercel/project.json` |
| Variable | `VERCEL_PROJECT_ID` | `projectId` de `.vercel/project.json` |
| Variable | `SUPABASE_URL` | `https://zcxmvexdzqlrpbamofie.supabase.co` |
| Variable | `SUPABASE_ANON_KEY` | clé anon (publique) du projet Supabase |

Ne jamais mettre la clé `service_role` dans la CI ni dans l'app.

Sans ces valeurs, la CI fait quand même analyse, tests et build, mais ne
déploie pas (un avertissement le signale).

## 3. Configurer Supabase Auth (tableau de bord → Authentication)

**URL Configuration**

- *Site URL* : `https://<nom-du-projet>.vercel.app`
- *Redirect URLs* :
  - `https://<nom-du-projet>.vercel.app/**`
  - `https://<nom-du-projet>-*-<équipe>.vercel.app/**` (aperçus de PR)
  - `http://localhost:*/**` (développement local)

Les liens de confirmation d'inscription et de réinitialisation du mot de
passe renvoient vers le site qui les a demandés ; une URL absente de cette
liste est remplacée par la *Site URL*.

**Emails (obligatoire avant d'ouvrir l'inscription)**

Le service d'email intégré de Supabase n'envoie qu'aux membres de l'équipe
du projet, avec une limite de quelques emails par heure. Configurer un SMTP
(Authentication → Emails → SMTP Settings : Resend, Brevo, Postmark…), sinon
les étudiants ne recevront ni la confirmation d'inscription ni le lien de
réinitialisation.

**Sécurité**

- Activer *Leaked password protection* (Authentication → Policies /
  Passwords).
- Longueur minimale du mot de passe : 8, comme l'app.
- L'inscription n'accepte que les domaines de `allowed_email_domains`
  (trigger `validate_student_email`) : vérifier que les domaines de
  l'université y sont actifs.

## 4. Déployer

Fusionner sur `main` (ou lancer le workflow *Web* à la main depuis
l'onglet Actions). L'URL déployée apparaît dans le résumé du job.

## Vérifier après le premier déploiement

- Ouvrir une route directement (`/courses`) : la page doit s'afficher, pas
  une 404.
- Créer un compte, confirmer l'email, se connecter.
- « Mot de passe oublié ? » : le lien reçu ouvre *Nouveau mot de passe*.
- Publier une course depuis un compte, l'accepter depuis un autre (fenêtre
  privée) : le suivi se met à jour sans recharger.
- Console du navigateur : aucune erreur `Content-Security-Policy`.

## Ce qui ne fonctionne pas encore sur le web

- **Notifications push** : désactivées sur le web. Il faudrait la config
  web Firebase (`firebase_options.dart`), une clé VAPID et un service worker
  `firebase-messaging-sw.js`. Les notifications restent visibles dans l'app
  via le temps réel.
- **Domaine personnalisé** : à ajouter dans Vercel (Settings → Domains), puis
  mettre à jour la *Site URL* et les *Redirect URLs* de Supabase.

## En-têtes et cache

`deploy/vercel/config.json` définit :

- la CSP (scripts du site uniquement, WebAssembly autorisé pour CanvasKit,
  connexions vers `*.supabase.co` et les polices Google), `X-Frame-Options`,
  `Referrer-Policy`, `Permissions-Policy` ;
- `Cache-Control: no-cache` sur `index.html`, `main.dart.js` et
  `flutter_bootstrap.js`, dont les noms ne changent pas d'une version à
  l'autre ;
- la réécriture de toutes les routes vers `index.html` (URLs sans `#`).

Toute nouvelle origine appelée par l'app (API, CDN) doit être ajoutée à
`connect-src`.
