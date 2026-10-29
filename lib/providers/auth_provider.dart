import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snack_runner/models/user_profile.dart';
import 'package:snack_runner/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client),
);

/// Identifiant de l'utilisateur connecté, mis à jour à chaque changement
/// de session (connexion, déconnexion, expiration).
final currentUserIdProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(authRepositoryProvider);
  yield auth.currentUserId;
  yield* auth.userIdChanges();
});

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider).valueOrNull;
  if (userId == null) return null;
  return ref.watch(authRepositoryProvider).fetchProfile();
});
