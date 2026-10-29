/// Rôle de l'utilisateur, aligné sur l'enum Postgres `user_role`.
///
/// Seuls les utilisateurs `runner` reçoivent les notifications de nouvelles
/// courses (Edge Function notify-new-errand).
enum UserRole {
  requester('requester'),
  runner('runner'),
  admin('admin');

  const UserRole(this.dbValue);

  final String dbValue;

  static UserRole fromDb(String? value) => values.firstWhere(
    (role) => role.dbValue == value,
    orElse: () => UserRole.requester,
  );
}

/// Profil public (table `users`). L'email n'est pas lisible par les clients.
class UserProfile {
  final String id;
  final String nom;
  final UserRole role;
  final double rating;
  final int nombreCourses;

  const UserProfile({
    required this.id,
    required this.nom,
    required this.role,
    this.rating = 0,
    this.nombreCourses = 0,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: map['id'] as String,
    nom: map['nom'] as String,
    role: UserRole.fromDb(map['role'] as String?),
    rating: ((map['rating'] as num?) ?? 0).toDouble(),
    nombreCourses: (map['nombre_courses'] as int?) ?? 0,
  );

  UserProfile copyWith({UserRole? role}) => UserProfile(
    id: id,
    nom: nom,
    role: role ?? this.role,
    rating: rating,
    nombreCourses: nombreCourses,
  );
}
