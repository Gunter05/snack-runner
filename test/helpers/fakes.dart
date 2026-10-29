import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/core/errors.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/models/user_profile.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/repositories/auth_repository.dart';
import 'package:snack_runner/repositories/course_repository.dart';
import 'package:snack_runner/router/app_router.dart';
import 'package:snack_runner/theme/app_theme.dart';

const aliceId = '00000000-0000-0000-0000-00000000000a';
const bobId = '00000000-0000-0000-0000-00000000000b';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? userId, this.password = 'motdepasse'})
    : _userId = userId;

  final String password;
  final _changes = StreamController<String?>.broadcast();
  String? _userId;
  final roles = <UserRole>[];
  final signUps = <String>[];
  final passwordResets = <String>[];
  final newPasswords = <String>[];

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> userIdChanges() => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (password != this.password) {
      throw const AppException('Email ou mot de passe incorrect');
    }
    _userId = aliceId;
    _changes.add(_userId);
  }

  @override
  Future<bool> signUp({
    required String nom,
    required String email,
    required String password,
  }) async {
    signUps.add(email);
    return false;
  }

  @override
  Future<void> signOut() async {
    _userId = null;
    _changes.add(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async =>
      passwordResets.add(email.trim());

  @override
  Future<void> updatePassword(String password) async =>
      newPasswords.add(password);

  @override
  Future<UserProfile?> fetchProfile() async => _userId == null
      ? null
      : UserProfile(id: _userId!, nom: 'Alice', role: UserRole.requester);

  @override
  Future<void> updateRole(UserRole role) async => roles.add(role);
}

class FakeCourseRepository implements CourseRepository {
  FakeCourseRepository({required this.userId, List<Course> courses = const []})
    : courses = [...courses];

  final String userId;
  final List<Course> courses;
  final _changes = StreamController<List<Course>>.broadcast();
  final reviews = <String>[];
  var _nextId = 1;

  void _emit() => _changes.add(List.unmodifiable(courses));

  void _update(String id, Course Function(Course) change) {
    final index = courses.indexWhere((c) => c.id == id);
    courses[index] = change(courses[index]);
    _emit();
  }

  @override
  Stream<List<Course>> watchCourses() async* {
    yield List.unmodifiable(courses);
    yield* _changes.stream;
  }

  @override
  Future<Course> create(CourseDraft draft) async {
    final course = Course(
      id: 'new-${_nextId++}',
      category: draft.category,
      title: draft.title,
      description: draft.description,
      pickupLocation: draft.pickupLocation,
      deliveryLocation: draft.deliveryLocation,
      rewardType: draft.rewardType,
      rewardAmount: draft.rewardAmount,
      rewardDescription: draft.rewardDescription,
      status: CourseStatus.enAttente,
      requesterId: userId,
      requesterName: 'Alice',
      createdAt: DateTime.now(),
    );
    courses.insert(0, course);
    _emit();
    return course;
  }

  @override
  Future<void> accept(String courseId) async => _update(
    courseId,
    (c) => _copy(c, status: CourseStatus.acceptee, runnerId: userId),
  );

  @override
  Future<void> startDelivery(String courseId) async =>
      _update(courseId, (c) => _copy(c, status: CourseStatus.livraison));

  @override
  Future<void> complete(String courseId) async =>
      _update(courseId, (c) => _copy(c, status: CourseStatus.terminee));

  @override
  Future<void> cancel(String courseId) async =>
      _update(courseId, (c) => _copy(c, status: CourseStatus.annulee));

  @override
  Future<bool> hasReviewed(String courseId) async => reviews.contains(courseId);

  @override
  Future<void> review({
    required Course course,
    required int note,
    String? commentaire,
  }) async => reviews.add(course.id);
}

Course _copy(Course c, {CourseStatus? status, String? runnerId}) => Course(
  id: c.id,
  category: c.category,
  title: c.title,
  description: c.description,
  pickupLocation: c.pickupLocation,
  deliveryLocation: c.deliveryLocation,
  rewardType: c.rewardType,
  rewardAmount: c.rewardAmount,
  rewardDescription: c.rewardDescription,
  status: status ?? c.status,
  requesterId: c.requesterId,
  requesterName: c.requesterName,
  runnerId: runnerId ?? c.runnerId,
  runnerName: runnerId != null ? 'Alice' : c.runnerName,
  createdAt: c.createdAt,
);

Course sampleCourse({
  String id = 'c1',
  String requesterId = bobId,
  String requesterName = 'Bob',
  String? runnerId,
  CourseStatus status = CourseStatus.enAttente,
  double amount = 500,
  DateTime? createdAt,
}) => Course(
  id: id,
  category: CourseCategory.cafeteria,
  title: 'Sandwich thon',
  description: 'Sandwich thon',
  pickupLocation: 'Cafét RU B',
  deliveryLocation: 'Amphi 3',
  rewardType: RewardType.argent,
  rewardAmount: amount,
  status: status,
  requesterId: requesterId,
  requesterName: requesterName,
  runnerId: runnerId,
  createdAt: createdAt ?? DateTime.now(),
);

extension GoRouterLocation on GoRouter {
  /// Chemin de la page affichée.
  String get location =>
      routerDelegate.currentConfiguration.last.matchedLocation;
}

/// Lance l'application complète (vrai routeur) sur des dépôts factices.
Future<GoRouter> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  FakeCourseRepository? courses,
  String? initialLocation,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      courseRepositoryProvider.overrideWithValue(
        courses ?? FakeCourseRepository(userId: aliceId),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.theme, routerConfig: router),
    ),
  );
  if (initialLocation != null) router.go(initialLocation);
  await tester.pumpAndSettle();
  return router;
}
