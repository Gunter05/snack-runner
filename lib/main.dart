import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/router/app_router.dart';
import 'package:snack_runner/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
  AppRouter.notifyAuthChanged(isLoggedIn);

  runApp(ProviderScope(child: SnackRunnerApp(initialAuth: isLoggedIn)));
}

class SnackRunnerApp extends ConsumerStatefulWidget {
  final bool initialAuth;
  const SnackRunnerApp({super.key, required this.initialAuth});

  @override
  ConsumerState<SnackRunnerApp> createState() => _SnackRunnerAppState();
}

class _SnackRunnerAppState extends ConsumerState<SnackRunnerApp> {
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter(isLoggedIn: widget.initialAuth);
    ref.read(authProvider); // démarre l'écoute de la session Supabase
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SnackRunner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      themeMode: ThemeMode.dark,
      routerConfig: _router.router,
    );
  }
}
