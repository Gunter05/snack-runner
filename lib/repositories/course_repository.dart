import 'dart:async';

import 'package:snack_runner/core/errors.dart';
import 'package:snack_runner/models/course.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CourseRepository {
  /// Courses visibles par l'utilisateur (RLS : courses en attente, ses
  /// demandes et ses missions), mises à jour en temps réel.
  Stream<List<Course>> watchCourses();

  Future<Course> create(CourseDraft draft);

  Future<void> accept(String courseId);

  Future<void> startDelivery(String courseId);

  Future<void> complete(String courseId);

  Future<void> cancel(String courseId);

  /// Indique si l'utilisateur a déjà noté l'autre participant de la course.
  Future<bool> hasReviewed(String courseId);

  Future<void> review({
    required Course course,
    required int note,
    String? commentaire,
  });
}

class SupabaseCourseRepository implements CourseRepository {
  SupabaseCourseRepository(this._client);

  final SupabaseClient _client;

  static const _maxCourses = 200;
  static const _select =
      '*, requester:users!errands_requester_id_fkey(nom), '
      'runner:users!errands_runner_id_fkey(nom)';

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('Session expirée. Reconnecte-toi.');
    }
    return userId;
  }

  Future<List<Course>> _fetchCourses() async {
    final rows = await _client
        .from('errands')
        .select(_select)
        .order('created_at', ascending: false)
        .limit(_maxCourses);
    return rows.map(Course.fromMap).toList();
  }

  @override
  Stream<List<Course>> watchCourses() {
    late final StreamController<List<Course>> controller;
    RealtimeChannel? channel;

    Future<void> refresh() async {
      try {
        final courses = await _fetchCourses();
        if (!controller.isClosed) controller.add(courses);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<List<Course>>(
      onListen: () {
        // Les événements temps réel respectent la RLS : on relit la liste
        // complète pour récupérer aussi les noms joints.
        channel = _client
            .channel('errands-${DateTime.now().microsecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'errands',
              callback: (_) => refresh(),
            )
            .subscribe();
        refresh();
      },
      onCancel: () async {
        final current = channel;
        if (current != null) await _client.removeChannel(current);
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<Course> create(CourseDraft draft) async {
    final row = await _client
        .from('errands')
        .insert(draft.toInsertMap(_userId))
        .select(_select)
        .single();
    return Course.fromMap(row);
  }

  /// Applique un changement de statut et vérifie qu'une ligne a bien été
  /// modifiée : la RLS filtre silencieusement les lignes non autorisées.
  Future<void> _transition(
    String courseId, {
    required CourseStatus from,
    required CourseStatus to,
    Map<String, dynamic> extra = const {},
    required String conflictMessage,
  }) async {
    final rows = await _client
        .from('errands')
        .update({'status': to.dbValue, ...extra})
        .eq('id', courseId)
        .eq('status', from.dbValue)
        .select('id');
    if (rows.isEmpty) throw AppException(conflictMessage);
  }

  @override
  Future<void> accept(String courseId) => _transition(
    courseId,
    from: CourseStatus.enAttente,
    to: CourseStatus.acceptee,
    extra: {'runner_id': _userId},
    conflictMessage: 'Cette course n\'est plus disponible.',
  );

  @override
  Future<void> startDelivery(String courseId) => _transition(
    courseId,
    from: CourseStatus.acceptee,
    to: CourseStatus.livraison,
    conflictMessage: 'Impossible de démarrer cette livraison.',
  );

  @override
  Future<void> complete(String courseId) => _transition(
    courseId,
    from: CourseStatus.livraison,
    to: CourseStatus.terminee,
    conflictMessage: 'Impossible de terminer cette livraison.',
  );

  @override
  Future<void> cancel(String courseId) => _transition(
    courseId,
    from: CourseStatus.enAttente,
    to: CourseStatus.annulee,
    conflictMessage: 'Cette course ne peut plus être annulée.',
  );

  @override
  Future<bool> hasReviewed(String courseId) async {
    final row = await _client
        .from('reviews')
        .select('id')
        .eq('errand_id', courseId)
        .eq('reviewer_id', _userId)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> review({
    required Course course,
    required int note,
    String? commentaire,
  }) async {
    final userId = _userId;
    final reviewedUserId = course.isRequester(userId)
        ? course.runnerId
        : course.requesterId;
    if (reviewedUserId == null) {
      throw const AppException('Aucun participant à noter.');
    }
    final text = commentaire?.trim();
    await _client.from('reviews').insert({
      'errand_id': course.id,
      'reviewer_id': userId,
      'reviewed_user_id': reviewedUserId,
      'note': note,
      if (text != null && text.isNotEmpty) 'commentaire': text,
    });
  }
}
