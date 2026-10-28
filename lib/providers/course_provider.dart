import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course.dart';

/// false = données locales comme avant (en attendant les tables Supabase)
const bool kUseSupabase = true;

final courseProvider = StateNotifierProvider<CourseNotifier, List<Course>>(
  (ref) => CourseNotifier(),
);

class CourseNotifier extends StateNotifier<List<Course>> {
  CourseNotifier() : super(kUseSupabase ? const [] : _initialCourses) {
    if (kUseSupabase) _listen();
  }

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  SupabaseClient get _db => Supabase.instance.client;

  void _listen() {
    _sub = _db
        .from('courses')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen(
          (rows) => state = rows.map(Course.fromMap).toList(),
          onError: (_) => state = const [],
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  static const _initialCourses = [
    Course(
      id: '1',
      category: 'Cafétéria',
      title: 'Sandwich thon + jus d\'orange',
      pickupLocation: 'Cafét RU B',
      deliveryLocation: 'Amphi 3, Bâtiment B',
      reward: 500,
      rewardType: 'Argent',
      status: CourseStatus.enAttente,
      requesterName: 'Kofi',
      runnerName: '',
    ),
    Course(
      id: '2',
      category: 'Colis',
      title: 'Colis étudiant',
      pickupLocation: 'Bureau des étudiants',
      deliveryLocation: 'Résidence A',
      reward: 700,
      rewardType: 'Argent',
      status: CourseStatus.enAttente,
      requesterName: 'Amina',
      runnerName: '',
    ),
    Course(
      id: '3',
      category: 'Cafétéria',
      title: 'Salade + eau',
      pickupLocation: 'Cafét A',
      deliveryLocation: 'Bibliothèque',
      reward: 300,
      rewardType: 'Argent',
      status: CourseStatus.terminee,
      requesterName: 'Kofi',
      runnerName: 'Sam',
    ),
  ];

  void setCourses(List<Course> courses) => state = courses;

  Course? courseById(String id) {
    for (final c in state) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool isPublished(String courseId) => state.any((c) => c.id == courseId);

  void _replaceLocal(Course updated) {
    state = [
      for (final c in state)
        if (c.id == updated.id) updated else c,
    ];
  }

  /// Publie une course et renvoie son id (généré par Supabase).
  Future<String> addCourse(Course course) async {
    if (!kUseSupabase) {
      state = [...state, course];
      return course.id;
    }
    final row = await _db
        .from('courses')
        .insert(course.toInsertMap())
        .select('id')
        .single();
    return row['id'].toString();
  }

  Future<void> updateCourse(Course updated) async {
    if (!kUseSupabase) return _replaceLocal(updated);
    await _db
        .from('courses')
        .update(updated.toInsertMap())
        .eq('id', updated.id);
  }

  /// true si la course a bien été prise, false si elle ne l'est plus
  /// (déjà acceptée par un autre Runner).
  Future<bool> acceptCourse(String courseId, String runnerName) async {
    final c = courseById(courseId);
    if (c == null || !c.status.canTransitionTo(CourseStatus.acceptee)) {
      return false;
    }
    final accepted = c.copyWith(
      status: CourseStatus.acceptee,
      runnerName: runnerName,
    );
    if (!kUseSupabase) {
      _replaceLocal(accepted);
      return true;
    }
    final rows = await _db
        .from('courses')
        .update({
          'status': CourseStatus.acceptee.dbValue,
          'runner_id': _db.auth.currentUser!.id,
          'runner_name': runnerName,
        })
        .eq('id', courseId)
        .eq('status', CourseStatus.enAttente.dbValue)
        .select('id');
    if (rows.isEmpty) return false;
    _replaceLocal(
      accepted,
    ); // mise à jour immédiate, le flux Realtime confirmera
    return true;
  }

  Future<bool> _transition(String courseId, CourseStatus next) async {
    final c = courseById(courseId);
    if (c == null || !c.status.canTransitionTo(next)) return false;
    final updated = c.copyWith(status: next);
    if (!kUseSupabase) {
      _replaceLocal(updated);
      return true;
    }
    final rows = await _db
        .from('courses')
        .update({'status': next.dbValue})
        .eq('id', courseId)
        .eq('status', c.status.dbValue)
        .select('id');
    if (rows.isEmpty) return false;
    _replaceLocal(updated);
    return true;
  }

  Future<bool> startDelivery(String courseId) =>
      _transition(courseId, CourseStatus.livraison);

  Future<bool> completeCourse(String courseId, String runnerName) =>
      _transition(courseId, CourseStatus.terminee);
}
