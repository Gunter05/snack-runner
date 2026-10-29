import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';
import 'package:snack_runner/widgets/common.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  bool _isLoading = false;

  Future<void> _accept(Course course) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(courseRepositoryProvider).accept(course.id);
      if (!mounted) return;
      context.pushReplacement('/mission/${course.id}');
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
      appBar: darkAppBar('Détails de la course'),
      body: CourseLoader(
        courseId: widget.courseId,
        builder: (context, course) {
          return SingleChildScrollView(
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
                  '${course.category.label} • ${course.rewardLabel}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                if (_hasDetails(course))
                  InfoRow(label: 'Commande', value: course.description!),
                InfoRow(
                  label: 'Point de retrait',
                  value: course.pickupLocation,
                ),
                InfoRow(
                  label: 'Adresse de livraison',
                  value: course.deliveryLocation,
                ),
                InfoRow(label: 'Demandeur', value: course.requesterName),
                InfoRow(label: 'Statut', value: course.status.label),
                if (course.runnerName.isNotEmpty)
                  InfoRow(label: 'Runner', value: course.runnerName),
                const SizedBox(height: 24),
                if (course.status == CourseStatus.enAttente &&
                    !course.isRequester(userId))
                  PrimaryButton(
                    label: 'Accepter cette course',
                    isLoading: _isLoading,
                    onPressed: () => _accept(course),
                  ),
                if (course.status.isActive && course.isRunner(userId))
                  SecondaryButton(
                    label: 'Voir la mission',
                    onPressed: () => context.push('/mission/${course.id}'),
                  ),
                if (course.isRequester(userId))
                  SecondaryButton(
                    label: 'Suivre ma course',
                    onPressed: () => context.push('/suivi/${course.id}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// La description complète n'est affichée que si elle apporte plus que le
/// titre (qui en est la première ligne).
bool _hasDetails(Course course) {
  final description = course.description?.trim() ?? '';
  return description.isNotEmpty && description != course.title;
}
