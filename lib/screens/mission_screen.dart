import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';
import 'package:snack_runner/widgets/common.dart';

class MissionScreen extends ConsumerStatefulWidget {
  final String courseId;

  const MissionScreen({super.key, required this.courseId});

  @override
  ConsumerState<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends ConsumerState<MissionScreen> {
  bool _isLoading = false;

  Future<void> _startDelivery(Course course) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(courseRepositoryProvider).startDelivery(course.id);
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
      appBar: darkAppBar('Mission'),
      body: CourseLoader(
        courseId: widget.courseId,
        builder: (context, course) {
          final isRunner = course.isRunner(userId);
          final canStart = course.status == CourseStatus.acceptee && isRunner;
          final canComplete =
              course.status == CourseStatus.livraison && isRunner;
          final description = course.description?.trim() ?? '';

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.rewardLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (description.isNotEmpty &&
                              description != course.title)
                            InfoRow(
                              label: 'Commande',
                              value: description,
                              labelWidth: 100,
                            ),
                          InfoRow(
                            label: 'Retrait',
                            value: course.pickupLocation,
                            labelWidth: 100,
                          ),
                          InfoRow(
                            label: 'Livraison',
                            value: course.deliveryLocation,
                            labelWidth: 100,
                          ),
                          InfoRow(
                            label: 'Demandeur',
                            value: course.requesterName,
                            labelWidth: 100,
                          ),
                          InfoRow(
                            label: 'Statut',
                            value: course.status.label,
                            labelWidth: 100,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isRunner)
                    const Text(
                      "Tu n'es pas le runner de cette course.",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (canStart)
                    PrimaryButton(
                      label: 'Démarrer la livraison',
                      isLoading: _isLoading,
                      onPressed: () => _startDelivery(course),
                    ),
                  if (canComplete)
                    PrimaryButton(
                      label: 'Terminer la mission',
                      onPressed: () =>
                          context.push('/fin-mission/${course.id}'),
                    ),
                  if (isRunner && course.status == CourseStatus.terminee)
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
