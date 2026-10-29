import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Erreur métier dont le message peut être montré tel quel.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Messages levés par les triggers Postgres, et leur version affichée.
const _databaseMessages = {
  'Ce runner a déjà une course en cours.':
      "Tu as déjà une course en cours. Termine-la d'abord.",
  'Utilisez votre adresse email étudiante.':
      'Utilise ton adresse email étudiante',
};

/// Traduit une erreur technique en message lisible, sans exposer de détails
/// internes.
String friendlyError(Object error) {
  if (error is AppException) return error.message;

  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email ou mot de passe incorrect';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirme ton email avant de te connecter';
    }
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return 'Un compte existe déjà avec cet email';
    }
    if (message.contains('email non reconnu') ||
        message.contains('database error saving new user')) {
      return 'Utilise ton adresse email étudiante';
    }
    if (message.contains('password')) {
      return 'Mot de passe trop faible';
    }
    if (message.contains('rate limit') || error.statusCode == '429') {
      return 'Trop de tentatives. Réessaie dans quelques minutes.';
    }
  }

  if (error is PostgrestException) {
    for (final entry in _databaseMessages.entries) {
      if (error.message.contains(entry.key)) return entry.value;
    }
    if (error.code == '42501') {
      return 'Action non autorisée';
    }
  }

  if (error is TimeoutException || _isNetworkError(error)) {
    return 'Connexion impossible. Vérifie ton réseau.';
  }

  debugPrint('Erreur non gérée : $error');
  return 'Une erreur est survenue. Réessaie.';
}

bool _isNetworkError(Object error) {
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused');
}
