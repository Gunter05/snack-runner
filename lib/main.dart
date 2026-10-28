import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/providers/user_provider.dart';
import 'package:snack_runner/router/app_router.dart';
import 'package:snack_runner/services/auth_service.dart';
import 'package:snack_runner/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Le nom stocké localement ne suffit pas : il faut aussi une session
  // Supabase, sinon les requêtes partiraient en anon.
  var token = await AuthService().getToken();
  if (Supabase.instance.client.auth.currentSession == null && token != null) {
    await AuthService().clearToken();
    token = null;
  }
  final isLoggedIn = token != null;

  runApp(
    ProviderScope(
      child: SnackRunnerApp(initialAuth: isLoggedIn, initialUser: token ?? ''),
    ),
  );
}

class SnackRunnerApp extends ConsumerStatefulWidget {
  final bool initialAuth;
  final String initialUser;
  const SnackRunnerApp({
    super.key,
    required this.initialAuth,
    required this.initialUser,
  });

  @override
  ConsumerState<SnackRunnerApp> createState() => _SnackRunnerAppState();
}

class _SnackRunnerAppState extends ConsumerState<SnackRunnerApp> {
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter(isLoggedIn: widget.initialAuth);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialAuth) {
      ref.read(userProvider.notifier).state = widget.initialUser;
      ref.read(authProvider.notifier).login();
    }
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
