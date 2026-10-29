import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/repositories/course_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => SupabaseCourseRepository(Supabase.instance.client),
);

/// Courses visibles par l'utilisateur connecté, en temps réel.
final coursesProvider = StreamProvider<List<Course>>((ref) {
  final userId = ref.watch(currentUserIdProvider).valueOrNull;
  if (userId == null) return Stream.value(const []);
  return ref.watch(courseRepositoryProvider).watchCourses();
});

final courseByIdProvider = Provider.family<AsyncValue<Course?>, String>((
  ref,
  courseId,
) {
  return ref.watch(coursesProvider).whenData((courses) {
    for (final course in courses) {
      if (course.id == courseId) return course;
    }
    return null;
  });
});

final hasReviewedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, courseId) => ref.watch(courseRepositoryProvider).hasReviewed(courseId),
);
