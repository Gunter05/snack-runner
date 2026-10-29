import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:snack_runner/core/config.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/router/app_router.dart';
import 'package:snack_runner/services/push_notification_service.dart';
import 'package:snack_runner/theme/app_colors.dart';
import 'package:snack_runner/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Largeur maximale de l'app sur le web : l'interface est pensée pour un
/// téléphone et ne doit pas s'étirer sur un écran d'ordinateur.
const _maxAppWidth = 520.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // URLs sans « # » sur le web (/suivi/… au lieu de /#/suivi/…) ; l'hôte
  // renvoie toutes les routes vers index.html (deploy/vercel/config.json).
  usePathUrlStrategy();

  if (!AppConfig.isValid) {
    runApp(const ConfigErrorApp());
    return;
  }

  // La session est persistée et rafraîchie par supabase_flutter.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  final container = ProviderContainer();

  // Lien de réinitialisation : la session de récupération peut arriver
  // après le premier rendu ; on ouvre l'écran dès qu'elle est établie.
  Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    if (state.event == AuthChangeEvent.passwordRecovery) {
      container.read(routerProvider).go('/nouveau-mot-de-passe');
    }
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SnackRunnerApp(),
    ),
  );

  // Après runApp : une notification qui a lancé l'app ouvre son écran
  // une fois le routeur monté.
  await PushNotificationService.instance.initialize(
    onOpen: (location) => WidgetsBinding.instance.addPostFrameCallback(
      (_) => container.read(routerProvider).push(location),
    ),
    onForeground: (message) => scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    ),
  );
}

class SnackRunnerApp extends ConsumerWidget {
  const SnackRunnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentUserIdProvider, (previous, next) {
      final userId = next.valueOrNull;
      if (userId != null && userId != previous?.valueOrNull) {
        PushNotificationService.instance.registerForUser(
          Supabase.instance.client,
        );
      }
    });

    return MaterialApp.router(
      title: 'SnackRunner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // Textes Material (« Retour », « Coller »…) et attribut lang de la
      // page web en français.
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => ColoredBox(
        color: AppColors.bg0,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxAppWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Affiché si l'app a été compilée sans --dart-define-from-file=.env.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.bg0,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Configuration manquante : SUPABASE_URL et SUPABASE_ANON_KEY '
              'doivent être fournis à la compilation '
              '(--dart-define-from-file=.env).',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
