/// Configuration injectée à la compilation :
///   flutter run --dart-define-from-file=.env
/// (fichier .env au format CLE=valeur, voir .env.example).
///
/// Les valeurs ne sont plus embarquées comme asset lisible dans l'APK.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isValid =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;
}
