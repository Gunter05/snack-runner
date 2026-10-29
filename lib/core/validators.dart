/// Validateurs de formulaires. Chaque fonction renvoie le message d'erreur
/// à afficher, ou null si la valeur est valide.
class Validators {
  Validators._();

  static const minPasswordLength = 8;
  static const maxTextLength = 500;
  static const maxRewardAmount = 100000;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Email requis';
    if (!_emailPattern.hasMatch(email)) return 'Email invalide';
    return null;
  }

  /// Mot de passe à la connexion : seule la présence est vérifiée, pour ne
  /// pas bloquer les comptes créés avec d'anciennes règles.
  static String? loginPassword(String value) =>
      value.isEmpty ? 'Mot de passe requis' : null;

  static String? newPassword(String value) {
    if (value.isEmpty) return 'Mot de passe requis';
    if (value.length < minPasswordLength) {
      return 'Minimum $minPasswordLength caractères';
    }
    return null;
  }

  static String? confirmPassword(String password, String confirmation) =>
      password != confirmation
      ? 'Les mots de passe ne correspondent pas'
      : null;

  static String? required(String value, String message) {
    final text = value.trim();
    if (text.isEmpty) return message;
    if (text.length > maxTextLength) {
      return 'Maximum $maxTextLength caractères';
    }
    return null;
  }

  /// Montant en FCFA : entier strictement positif.
  static String? rewardAmount(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Montant requis';
    final amount = int.tryParse(text);
    if (amount == null) return 'Montant invalide';
    if (amount <= 0) return 'Le montant doit être supérieur à 0';
    if (amount > maxRewardAmount) return 'Montant trop élevé';
    return null;
  }
}
