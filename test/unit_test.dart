import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:snack_runner/core/errors.dart';
import 'package:snack_runner/core/validators.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/models/user_profile.dart';
import 'package:snack_runner/router/app_router.dart';
import 'package:snack_runner/screens/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fakes.dart';

void main() {
  group('Course.fromMap', () {
    final row = {
      'id': 'e1',
      'titre': 'Sandwich',
      'description': 'Sandwich thon + jus',
      'category': 'cafeteria',
      'pickup_location': 'Cafét RU B',
      'delivery_location': 'Amphi 3',
      'lieu': 'Amphi 3',
      'reward_type': 'argent',
      'reward_amount': 500,
      'reward_description': null,
      'status': 'delivering',
      'requester_id': bobId,
      'runner_id': aliceId,
      'created_at': '2026-10-29T10:00:00Z',
      'completed_at': null,
      'requester': {'nom': 'Bob'},
      'runner': {'nom': 'Alice'},
    };

    test('lit une ligne errands jointe aux profils', () {
      final course = Course.fromMap(row);
      expect(course.status, CourseStatus.livraison);
      expect(course.category, CourseCategory.cafeteria);
      expect(course.rewardAmount, 500);
      expect(course.rewardLabel, '500 FCFA');
      expect(course.requesterName, 'Bob');
      expect(course.runnerName, 'Alice');
      expect(course.isRunner(aliceId), isTrue);
      expect(course.isRequester(aliceId), isFalse);
      expect(course.isRequester(null), isFalse);
    });

    test('tolère un runner absent et les anciennes colonnes', () {
      final course = Course.fromMap({
        ...row,
        'status': 'waiting',
        'runner_id': null,
        'runner': null,
        'delivery_location': null,
        'pickup_location': null,
        'category': 'inconnue',
        'reward_type': 'nourriture',
        'reward_amount': null,
        'reward_description': 'Un café',
      });
      expect(course.runnerName, '');
      expect(course.deliveryLocation, 'Amphi 3');
      expect(course.pickupLocation, '');
      expect(course.category, CourseCategory.autre);
      expect(course.rewardLabel, 'Un café');
    });

    test('rejette un statut inconnu', () {
      expect(
        () => Course.fromMap({...row, 'status': 'lost'}),
        throwsFormatException,
      );
    });
  });

  group('CourseStatus', () {
    test('suit les transitions autorisées par la RLS', () {
      expect(
        CourseStatus.enAttente.canTransitionTo(CourseStatus.acceptee),
        isTrue,
      );
      expect(
        CourseStatus.enAttente.canTransitionTo(CourseStatus.annulee),
        isTrue,
      );
      expect(
        CourseStatus.acceptee.canTransitionTo(CourseStatus.livraison),
        isTrue,
      );
      expect(
        CourseStatus.livraison.canTransitionTo(CourseStatus.terminee),
        isTrue,
      );
      expect(
        CourseStatus.livraison.canTransitionTo(CourseStatus.annulee),
        isFalse,
      );
      expect(
        CourseStatus.terminee.canTransitionTo(CourseStatus.enAttente),
        isFalse,
      );
    });

    test('correspond aux valeurs de l\'enum Postgres', () {
      expect(CourseStatus.values.map((s) => s.dbValue), [
        'waiting',
        'accepted',
        'delivering',
        'done',
        'cancelled',
      ]);
      for (final status in CourseStatus.values) {
        expect(CourseStatus.fromDb(status.dbValue), status);
      }
    });
  });

  group('CourseDraft', () {
    test('argent : montant envoyé, description de récompense nulle', () {
      const draft = CourseDraft(
        category: CourseCategory.colis,
        description: '  Colis au BDE\nfragile  ',
        pickupLocation: ' BDE ',
        deliveryLocation: ' Résidence A ',
        rewardType: RewardType.argent,
        rewardAmount: 700,
        rewardDescription: 'ignorée',
      );
      final map = draft.toInsertMap(aliceId);
      expect(map['titre'], 'Colis au BDE');
      expect(map['description'], 'Colis au BDE\nfragile');
      expect(map['category'], 'colis');
      expect(map['pickup_location'], 'BDE');
      expect(map['delivery_location'], 'Résidence A');
      expect(map['lieu'], 'Résidence A');
      expect(map['reward_type'], 'argent');
      expect(map['reward_amount'], 700);
      expect(map['reward_description'], isNull);
      expect(map['requester_id'], aliceId);
      expect(map.containsKey('runner_id'), isFalse);
      expect(map.containsKey('status'), isFalse);
    });

    test('nourriture : description requise par la contrainte errands', () {
      const draft = CourseDraft(
        category: CourseCategory.autre,
        description: 'Photocopies',
        pickupLocation: 'Bibliothèque',
        deliveryLocation: 'Amphi 1',
        rewardType: RewardType.nourriture,
        rewardAmount: 300,
        rewardDescription: ' Un croissant ',
      );
      final map = draft.toInsertMap(aliceId);
      expect(map['reward_amount'], isNull);
      expect(map['reward_description'], 'Un croissant');
      expect(draft.rewardLabel, 'Un croissant');
    });

    test('tronque les titres trop longs', () {
      final draft = CourseDraft(
        category: CourseCategory.autre,
        description: 'x' * 200,
        pickupLocation: 'A',
        deliveryLocation: 'B',
        rewardType: RewardType.argent,
        rewardAmount: 100,
      );
      expect(draft.title.length, CourseDraft.maxTitleLength);
      expect(draft.title.endsWith('…'), isTrue);
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), 'Email requis');
      expect(Validators.email('kofi'), 'Email invalide');
      expect(Validators.email('kofi@univ'), 'Email invalide');
      expect(Validators.email(' kofi@univ.cm '), isNull);
    });

    test('mots de passe', () {
      expect(Validators.loginPassword(''), 'Mot de passe requis');
      expect(Validators.loginPassword('abc'), isNull);
      expect(Validators.newPassword('abc'), contains('Minimum'));
      expect(Validators.newPassword('abcdefgh'), isNull);
      expect(Validators.confirmPassword('a', 'b'), isNotNull);
      expect(Validators.confirmPassword('a', 'a'), isNull);
    });

    test('montant', () {
      expect(Validators.rewardAmount(''), 'Montant requis');
      expect(Validators.rewardAmount('abc'), 'Montant invalide');
      expect(Validators.rewardAmount('12.5'), 'Montant invalide');
      expect(Validators.rewardAmount('0'), contains('supérieur à 0'));
      expect(Validators.rewardAmount('-5'), contains('supérieur à 0'));
      expect(Validators.rewardAmount('1000000'), 'Montant trop élevé');
      expect(Validators.rewardAmount(' 500 '), isNull);
    });

    test('texte requis et longueur maximale', () {
      expect(Validators.required('   ', 'Requis'), 'Requis');
      expect(Validators.required('ok', 'Requis'), isNull);
      expect(Validators.required('x' * 501, 'Requis'), contains('Maximum'));
    });
  });

  group('friendlyError', () {
    test('traduit les erreurs d\'authentification', () {
      expect(
        friendlyError(const AuthException('Invalid login credentials')),
        'Email ou mot de passe incorrect',
      );
      expect(
        friendlyError(const AuthException('Email not confirmed')),
        contains('Confirme ton email'),
      );
      expect(
        friendlyError(const AuthException('User already registered')),
        contains('existe déjà'),
      );
      expect(
        friendlyError(const AuthException('Database error saving new user')),
        contains('email étudiante'),
      );
    });

    test('reprend les messages des triggers Postgres', () {
      expect(
        friendlyError(
          const PostgrestException(
            message: 'Ce runner a déjà une course en cours.',
          ),
        ),
        contains('déjà une course en cours'),
      );
      expect(
        friendlyError(
          const PostgrestException(message: 'denied', code: '42501'),
        ),
        'Action non autorisée',
      );
    });

    test('masque les détails techniques', () {
      expect(
        friendlyError(TimeoutException('x')),
        contains('Connexion impossible'),
      );
      expect(
        friendlyError(Exception('SocketException: Failed host lookup')),
        contains('Connexion impossible'),
      );
      expect(
        friendlyError(StateError('stack trace interne')),
        'Une erreur est survenue. Réessaie.',
      );
      expect(friendlyError(const AppException('Message')), 'Message');
    });
  });

  group('authRedirect', () {
    test('envoie vers la connexion sans session', () {
      expect(authRedirect(loggedIn: false, location: '/dashboard'), '/login');
      expect(authRedirect(loggedIn: false, location: '/suivi/1'), '/login');
      expect(authRedirect(loggedIn: false, location: '/login'), isNull);
      expect(authRedirect(loggedIn: false, location: '/inscription'), isNull);
    });

    test('envoie vers le tableau de bord avec une session', () {
      expect(authRedirect(loggedIn: true, location: '/login'), '/dashboard');
      expect(
        authRedirect(loggedIn: true, location: '/inscription'),
        '/dashboard',
      );
      expect(authRedirect(loggedIn: true, location: '/suivi/1'), isNull);
    });
  });

  group('DashboardStats', () {
    final now = DateTime(2026, 10, 29);

    test('calcule les chiffres du demandeur et du runner', () {
      final courses = [
        sampleCourse(id: 'w', requesterId: aliceId, createdAt: now),
        sampleCourse(
          id: 'd1',
          requesterId: aliceId,
          runnerId: bobId,
          status: CourseStatus.terminee,
          amount: 300,
          createdAt: now,
        ),
        sampleCourse(
          id: 'old',
          requesterId: aliceId,
          status: CourseStatus.annulee,
          createdAt: DateTime(2026, 9, 1),
        ),
        sampleCourse(
          id: 'mission',
          runnerId: aliceId,
          status: CourseStatus.livraison,
        ),
        sampleCourse(
          id: 'earned',
          runnerId: aliceId,
          status: CourseStatus.terminee,
          amount: 700,
        ),
        sampleCourse(id: 'dispo'),
      ];

      final stats = DashboardStats.from(courses, aliceId, now: now);
      expect(stats.myCourses.map((c) => c.id), ['w', 'd1', 'old']);
      expect(stats.activeCourse?.id, 'w');
      expect(stats.postedThisMonth, 2);
      expect(stats.paidRewards, 300);
      expect(stats.activeMission?.id, 'mission');
      expect(stats.completedMissions, 1);
      expect(stats.earnings, 700);
      expect(stats.available.map((c) => c.id), ['dispo']);
    });

    test('ne présente pas une course terminée comme en cours', () {
      final stats = DashboardStats.from([
        sampleCourse(requesterId: aliceId, status: CourseStatus.terminee),
      ], aliceId);
      expect(stats.activeCourse, isNull);
    });
  });

  test('UserProfile lit le rôle et les compteurs', () {
    final profile = UserProfile.fromMap({
      'id': aliceId,
      'nom': 'Alice',
      'role': 'runner',
      'rating': 4.5,
      'nombre_courses': 3,
    });
    expect(profile.role, UserRole.runner);
    expect(profile.rating, 4.5);
    expect(profile.nombreCourses, 3);
  });
}
