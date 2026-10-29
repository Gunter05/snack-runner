import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';
import 'package:snack_runner/widgets/common.dart';
import 'package:snack_runner/widgets/course_card.dart';

/// Courses en attente publiées par les autres utilisateurs.
List<Course> availableCourses(List<Course> courses, String? userId) => courses
    .where(
      (course) =>
          course.status == CourseStatus.enAttente &&
          !course.isRequester(userId),
    )
    .toList();

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: darkAppBar('Courses disponibles'),
      body: ref
          .watch(coursesProvider)
          .when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(coursesProvider),
            ),
            data: (courses) {
              final waitingCourses = availableCourses(courses, userId);

              if (waitingCourses.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.bg3,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.amber,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune course disponible',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Revenez plus tard pour accepter une mission.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: 'Retour au tableau de bord',
                          onPressed: () => context.go('/dashboard'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.amber,
                onRefresh: () => ref.refresh(coursesProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: waitingCourses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final course = waitingCourses[index];
                    return CourseCard(
                      course: course,
                      onTap: () => context.push('/course/${course.id}'),
                    );
                  },
                ),
              );
            },
          ),
    );
  }
}
