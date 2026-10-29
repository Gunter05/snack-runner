import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/models/user_profile.dart';

import 'helpers/fakes.dart';

void main() {
  group('Authentification', () {
    testWidgets('sans session, l\'app ouvre la connexion', (tester) async {
      final router = await pumpApp(tester, auth: FakeAuthRepository());
      expect(router.location, '/login');
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('valide le formulaire puis connecte', (tester) async {
      final auth = FakeAuthRepository();
      final router = await pumpApp(tester, auth: auth);

      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Email requis'), findsOneWidget);
      expect(find.text('Mot de passe requis'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'alice@univ.cm');
      await tester.enterText(fields.at(1), 'mauvais');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Email ou mot de passe incorrect'), findsOneWidget);
      expect(router.location, '/login');

      await tester.enterText(fields.at(1), 'motdepasse');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(router.location, '/dashboard');
      expect(find.text('Bonjour, Alice'), findsOneWidget);
    });

    testWidgets('l\'inscription exige un mot de passe de 8 caractères', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      final router = await pumpApp(
        tester,
        auth: auth,
        initialLocation: '/inscription',
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Alice');
      await tester.enterText(fields.at(1), 'alice@univ.cm');
      await tester.enterText(fields.at(2), 'court');
      await tester.enterText(fields.at(3), 'court');
      await tester.tap(find.text('Créer mon compte'));
      await tester.pumpAndSettle();
      expect(find.text('Minimum 8 caractères'), findsOneWidget);
      expect(auth.signUps, isEmpty);

      await tester.enterText(fields.at(2), 'motdepasse');
      await tester.enterText(fields.at(3), 'motdepasse');
      await tester.tap(find.text('Créer mon compte'));
      await tester.pumpAndSettle();
      expect(auth.signUps, ['alice@univ.cm']);
      expect(router.location, '/login');
    });

    testWidgets('la déconnexion ramène à l\'écran de connexion', (
      tester,
    ) async {
      final router = await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: aliceId),
      );
      expect(router.location, '/dashboard');

      await tester.tap(find.byTooltip('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(router.location, '/login');
    });

    testWidgets('mot de passe oublié : envoie le lien à l\'email saisi', (
      tester,
    ) async {
      final auth = FakeAuthRepository();
      await pumpApp(tester, auth: auth);

      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
      expect(
        find.text('Saisis ton email pour recevoir le lien'),
        findsOneWidget,
      );
      expect(auth.passwordResets, isEmpty);

      await tester.enterText(find.byType(TextField).first, 'alice@univ.cm');
      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();
      expect(auth.passwordResets, ['alice@univ.cm']);
      expect(find.textContaining('Si un compte existe'), findsOneWidget);
    });

    testWidgets('nouveau mot de passe depuis le lien de réinitialisation', (
      tester,
    ) async {
      final auth = FakeAuthRepository(userId: aliceId);
      final router = await pumpApp(
        tester,
        auth: auth,
        initialLocation: '/nouveau-mot-de-passe',
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'nouveaumdp');
      await tester.enterText(fields.at(1), 'different');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Les mots de passe ne correspondent pas'),
        findsOneWidget,
      );

      await tester.enterText(fields.at(1), 'nouveaumdp');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(auth.newPasswords, ['nouveaumdp']);
      expect(router.location, '/dashboard');
    });

    testWidgets('lien de réinitialisation expiré : retour à la connexion', (
      tester,
    ) async {
      final router = await pumpApp(
        tester,
        auth: FakeAuthRepository(),
        initialLocation: '/nouveau-mot-de-passe',
      );
      expect(router.location, '/login');
    });
  });

  group('Demandeur', () {
    testWidgets('publie une course de bout en bout', (tester) async {
      final courses = FakeCourseRepository(userId: aliceId);
      final router = await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: aliceId),
        courses: courses,
      );

      expect(find.text('Aucune course récente'), findsOneWidget);
      await tester.tap(find.text('Nouvelle course'));
      await tester.pumpAndSettle();
      expect(router.location, '/nouvelle-course');

      await tester.tap(find.text('Voir le récapitulatif →'));
      await tester.pumpAndSettle();
      expect(find.text('Description requise'), findsOneWidget);
      expect(find.text('Montant requis'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '2 sandwichs poulet');
      await tester.enterText(fields.at(1), 'Cafét RU B');
      await tester.enterText(fields.at(2), 'Amphi 3');
      await tester.enterText(fields.at(3), '0');
      await tester.tap(find.text('Voir le récapitulatif →'));
      await tester.pumpAndSettle();
      expect(find.text('Le montant doit être supérieur à 0'), findsOneWidget);

      await tester.enterText(fields.at(3), '500');
      await tester.tap(find.text('Voir le récapitulatif →'));
      await tester.pumpAndSettle();
      expect(router.location, '/recapitulatif');
      expect(find.text('500 FCFA'), findsOneWidget);

      await tester.tap(find.text('Confirmer la publication'));
      await tester.pumpAndSettle();
      expect(courses.courses, hasLength(1));
      expect(courses.courses.single.title, '2 sandwichs poulet');
      expect(router.location, '/suivi/new-1');
      expect(
        find.text('Ta course est publiée et attend un runner.'),
        findsOneWidget,
      );

      // Le formulaire a quitté la pile : retour = tableau de bord.
      router.pop();
      await tester.pumpAndSettle();
      expect(router.location, '/dashboard');
      expect(find.text('2 sandwichs poulet'), findsWidgets);
    });

    testWidgets('une récompense en nourriture doit être décrite', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: aliceId),
        initialLocation: '/nouvelle-course',
      );

      await tester.tap(find.text('Nourriture'));
      await tester.pumpAndSettle();
      expect(find.text('RÉCOMPENSE PROPOSÉE'), findsOneWidget);
      expect(find.text('MONTANT'), findsNothing);

      await tester.tap(find.text('Voir le récapitulatif →'));
      await tester.pumpAndSettle();
      expect(find.text('Décris la récompense'), findsOneWidget);
    });

    testWidgets('annule une course en attente', (tester) async {
      final courses = FakeCourseRepository(
        userId: aliceId,
        courses: [sampleCourse(requesterId: aliceId, requesterName: 'Alice')],
      );
      await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: aliceId),
        courses: courses,
        initialLocation: '/suivi/c1',
      );

      await tester.tap(find.text('Annuler la course'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oui, annuler'));
      await tester.pumpAndSettle();
      expect(courses.courses.single.status, CourseStatus.annulee);
      expect(find.text('La course a été annulée.'), findsOneWidget);
      expect(find.text('Annuler la course'), findsNothing);
    });

    testWidgets('note le runner une fois la course livrée', (tester) async {
      final courses = FakeCourseRepository(
        userId: aliceId,
        courses: [
          sampleCourse(
            requesterId: aliceId,
            runnerId: bobId,
            status: CourseStatus.terminee,
          ),
        ],
      );
      await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: aliceId),
        courses: courses,
        initialLocation: '/suivi/c1',
      );

      expect(find.text('Note ton runner'), findsOneWidget);
      await tester.tap(find.byTooltip('4 sur 5'));
      await tester.pump();
      await tester.tap(find.text('Envoyer ma note'));
      await tester.pumpAndSettle();
      expect(courses.reviews, ['c1']);
      expect(find.text('Tu as noté cette course.'), findsOneWidget);
    });
  });

  group('Runner', () {
    testWidgets('accepte, livre et termine une course', (tester) async {
      final auth = FakeAuthRepository(userId: aliceId);
      final courses = FakeCourseRepository(
        userId: aliceId,
        courses: [sampleCourse()],
      );
      final router = await pumpApp(tester, auth: auth, courses: courses);

      // Passer en mode runner met à jour le rôle (push des nouvelles
      // courses).
      await tester.tap(find.text('Runner'));
      await tester.pumpAndSettle();
      expect(auth.roles, [UserRole.runner]);
      expect(find.text('Sandwich thon'), findsOneWidget);

      await tester.tap(find.text('Voir les courses dispo'));
      await tester.pumpAndSettle();
      expect(router.location, '/courses');

      await tester.tap(find.text('Sandwich thon'));
      await tester.pumpAndSettle();
      expect(router.location, '/course/c1');

      await tester.tap(find.text('Accepter cette course'));
      await tester.pumpAndSettle();
      expect(router.location, '/mission/c1');
      expect(courses.courses.single.runnerId, aliceId);

      await tester.tap(find.text('Démarrer la livraison'));
      await tester.pumpAndSettle();
      expect(courses.courses.single.status, CourseStatus.livraison);

      await tester.tap(find.text('Terminer la mission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider la livraison'));
      await tester.pumpAndSettle();
      expect(courses.courses.single.status, CourseStatus.terminee);
      expect(router.location, '/dashboard');
    });

    testWidgets('ne voit pas ses propres courses dans la liste', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(userId: aliceId),
        courses: FakeCourseRepository(
          userId: aliceId,
          courses: [sampleCourse(requesterId: aliceId)],
        ),
        initialLocation: '/courses',
      );
      expect(find.text('Aucune course disponible'), findsOneWidget);
    });
  });

  testWidgets('un lien vers une course inconnue reste affichable', (
    tester,
  ) async {
    await pumpApp(
      tester,
      auth: FakeAuthRepository(userId: aliceId),
      initialLocation: '/mission/inconnue',
    );
    expect(find.text('Course introuvable.'), findsOneWidget);
  });

  testWidgets('le récapitulatif sans brouillon renvoie au formulaire', (
    tester,
  ) async {
    final router = await pumpApp(
      tester,
      auth: FakeAuthRepository(userId: aliceId),
      initialLocation: '/recapitulatif',
    );
    expect(router.location, '/nouvelle-course');
  });
}
