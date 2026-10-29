import 'package:snack_runner/models/user_profile.dart';
import 'package:snack_runner/services/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  /// Identifiant de l'utilisateur connecté, ou null.
  String? get currentUserId;

  /// Émet l'identifiant de l'utilisateur à chaque changement de session.
  Stream<String?> userIdChanges();

  Future<void> signIn({required String email, required String password});

  /// Crée le compte. Renvoie true si une session est ouverte directement
  /// (confirmation d'email désactivée), false si l'email doit être confirmé.
  Future<bool> signUp({
    required String nom,
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<UserProfile?> fetchProfile();

  Future<void> updateRole(UserRole role);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Stream<String?> userIdChanges() =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user.id);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _client.auth.signInWithPassword(email: email.trim(), password: password);

  @override
  Future<bool> signUp({
    required String nom,
    required String email,
    required String password,
  }) async {
    // Le profil public.users est créé par le trigger handle_new_user à
    // partir du nom passé ici.
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'nom': nom.trim()},
    );
    return response.session != null;
  }

  @override
  Future<void> signOut() async {
    await PushNotificationService.instance.unregister(_client);
    await _client.auth.signOut();
  }

  @override
  Future<UserProfile?> fetchProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await _client
        .from('users')
        .select('id, nom, role, rating, nombre_courses')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : UserProfile.fromMap(row);
  }

  @override
  Future<void> updateRole(UserRole role) async {
    final userId = currentUserId;
    if (userId == null || role == UserRole.admin) return;
    await _client.from('users').update({'role': role.dbValue}).eq('id', userId);
  }
}
