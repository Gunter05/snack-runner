import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notifications push FCM. Toutes les erreurs sont absorbées : l'app doit
/// rester utilisable si Firebase n'est pas configuré sur la plateforme.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _available = false;
  String? _token;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _openedApp;
  StreamSubscription<RemoteMessage>? _foreground;

  String? get _platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => null,
  };

  /// À appeler une fois au démarrage. [onOpen] reçoit l'écran à ouvrir
  /// (champ `screen` du message), [onForeground] le texte d'un message reçu
  /// app ouverte.
  Future<void> initialize({
    required void Function(String location) onOpen,
    required void Function(String message) onForeground,
  }) async {
    if (kIsWeb || _platform == null) return;
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (error) {
      debugPrint('Firebase indisponible, push désactivé : $error');
      return;
    }

    void open(RemoteMessage message) {
      final screen = message.data['screen'];
      final errandId = message.data['errand_id'];
      if (screen is String && screen.startsWith('/')) {
        onOpen(screen);
      } else if (errandId is String && errandId.isNotEmpty) {
        // Nouvelle course : le runner arrive sur le détail pour l'accepter.
        onOpen('/course/$errandId');
      }
    }

    _openedApp = FirebaseMessaging.onMessageOpenedApp.listen(open);
    _foreground = FirebaseMessaging.onMessage.listen((message) {
      final body = message.notification?.body;
      if (body != null && body.isNotEmpty) onForeground(body);
    });
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) open(initial);
    } catch (error) {
      debugPrint('Lecture du message initial impossible : $error');
    }
  }

  /// Enregistre le token de l'appareil pour l'utilisateur connecté.
  Future<void> registerForUser(SupabaseClient client) async {
    final platform = _platform;
    if (!_available || platform == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null) await _saveToken(client, token, platform);

      await _tokenRefresh?.cancel();
      _tokenRefresh = messaging.onTokenRefresh.listen(
        (newToken) => _saveToken(client, newToken, platform),
      );
    } catch (error) {
      debugPrint('Enregistrement du token FCM impossible : $error');
    }
  }

  Future<void> _saveToken(
    SupabaseClient client,
    String token,
    String platform,
  ) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await client.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform,
      }, onConflict: 'token');
      _token = token;
    } catch (error) {
      debugPrint('Sauvegarde du token FCM impossible : $error');
    }
  }

  /// À appeler avant la déconnexion, tant que la session permet encore de
  /// supprimer la ligne : l'appareil ne doit plus recevoir les push du
  /// compte.
  Future<void> unregister(SupabaseClient client) async {
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    final token = _token;
    _token = null;
    if (!_available || token == null) return;
    try {
      await client.from('fcm_tokens').delete().eq('token', token);
    } catch (error) {
      debugPrint('Suppression du token FCM impossible : $error');
    }
  }

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
    await _openedApp?.cancel();
    await _foreground?.cancel();
  }
}
