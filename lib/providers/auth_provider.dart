import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../router/app_router.dart';
import 'course_provider.dart';

final authProvider = StateNotifierProvider<AuthNotifier, bool>(
  (ref) => AuthNotifier(ref),
);

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier(this._ref)
    : super(Supabase.instance.client.auth.currentSession != null) {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final loggedIn = data.session != null;
      if (loggedIn != state) _set(loggedIn);
    });
  }

  final Ref _ref;
  StreamSubscription<AuthState>? _sub;

  void _set(bool loggedIn) {
    final wasLoggedIn = state;
    state = loggedIn;
    AppRouter.notifyAuthChanged(loggedIn);
    if (wasLoggedIn && !loggedIn) {
      _ref.invalidate(courseProvider);
    }
  }

  void login() => _set(true);

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _set(false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
