import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';
import 'package:snack_runner/widgets/common.dart';

class FinMissionScreen extends ConsumerStatefulWidget {
  final String courseId;

  const FinMissionScreen({super.key, required this.courseId});

  @override
  ConsumerState<FinMissionScreen> createState() => _FinMissionScreenState();
}

class _FinMissionScreenState extends ConsumerState<FinMissionScreen> {
  bool _isLoading = false;

  Future<void> _complete(Course course) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(courseRepositoryProvider).complete(course.id);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Livraison validée. Merci !');
      context.go('/dashboard');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: darkAppBar('Fin de mission'),
      body: CourseLoader(
        courseId: widget.courseId,
        builder: (context, course) {
          final isCompleted = course.status == CourseStatus.terminee;
          final canComplete =
              course.status == CourseStatus.livraison &&
              course.isRunner(userId);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCompleted ? 'Mission terminée' : 'Terminer la livraison',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bg4,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Récompense',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          course.rewardLabel,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (canComplete)
                    PrimaryButton(
                      label: 'Valider la livraison',
                      isLoading: _isLoading,
                      onPressed: () => _complete(course),
                    )
                  else
                    PrimaryButton(
                      label: "Retour à l'accueil",
                      onPressed: () => context.go('/dashboard'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
