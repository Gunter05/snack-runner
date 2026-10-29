import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';
import 'package:snack_runner/widgets/common.dart';

String statusMessage(CourseStatus status) => switch (status) {
  CourseStatus.enAttente => 'Ta course est publiée et attend un runner.',
  CourseStatus.acceptee =>
    'Un runner a accepté la course. Prépare la livraison.',
  CourseStatus.livraison => 'La course est en cours de livraison.',
  CourseStatus.terminee => 'La course est terminée.',
  CourseStatus.annulee => 'La course a été annulée.',
};

class SuiviScreen extends ConsumerStatefulWidget {
  final String courseId;

  const SuiviScreen({super.key, required this.courseId});

  @override
  ConsumerState<SuiviScreen> createState() => _SuiviScreenState();
}

class _SuiviScreenState extends ConsumerState<SuiviScreen> {
  bool _isCancelling = false;

  Future<void> _cancel(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: const Text(
          'Annuler la course ?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Elle ne sera plus visible par les runners.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Oui, annuler',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await ref.read(courseRepositoryProvider).cancel(course.id);
      if (mounted) showSuccessSnackBar(context, 'Course annulée.');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: darkAppBar('Suivi de la course'),
      body: CourseLoader(
        courseId: widget.courseId,
        builder: (context, course) {
          final isRunner = course.isRunner(userId);
          final isRequester = course.isRequester(userId);

          return SafeArea(
            child: SingleChildScrollView(
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
                  _StatusChip(status: course.status),
                  const SizedBox(height: 20),
                  InfoRow(
                    label: 'Demandeur',
                    value: course.requesterName,
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
                  if (course.runnerName.isNotEmpty)
                    InfoRow(
                      label: 'Runner',
                      value: course.runnerName,
                      labelWidth: 100,
                    ),
                  const SizedBox(height: 24),
                  Text(
                    isRequester
                        ? 'Suivi de ta publication'
                        : 'Suivi de la mission',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusMessage(course.status),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (isRunner && course.status.isActive)
                    PrimaryButton(
                      label: 'Voir la mission',
                      onPressed: () => context.push('/mission/${course.id}'),
                    ),
                  if (isRequester && course.status == CourseStatus.enAttente)
                    _isCancelling
                        ? const LoadingView()
                        : SecondaryButton(
                            label: 'Annuler la course',
                            color: AppColors.danger,
                            onPressed: () => _cancel(course),
                          ),
                  if (course.status == CourseStatus.terminee &&
                      (isRunner || isRequester))
                    _ReviewSection(course: course, isRequester: isRequester),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final CourseStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: status.badgeBackground,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: status.badgeText,
        ),
      ),
    );
  }
}

/// Notation de l'autre participant une fois la course livrée (table
/// `reviews`, une note par participant et par course).
class _ReviewSection extends ConsumerStatefulWidget {
  final Course course;
  final bool isRequester;

  const _ReviewSection({required this.course, required this.isRequester});

  @override
  ConsumerState<_ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends ConsumerState<_ReviewSection> {
  int _note = 0;
  bool _isSending = false;

  Future<void> _send() async {
    setState(() => _isSending = true);
    try {
      await ref
          .read(courseRepositoryProvider)
          .review(course: widget.course, note: _note);
      ref.invalidate(hasReviewedProvider(widget.course.id));
      if (mounted) showSuccessSnackBar(context, 'Merci pour ta note !');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReviewed = ref.watch(hasReviewedProvider(widget.course.id));
    if (hasReviewed.valueOrNull != false) {
      return hasReviewed.valueOrNull == true
          ? const Text(
              'Tu as noté cette course.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            )
          : const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isRequester ? 'Note ton runner' : 'Note le demandeur',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                tooltip: '$star sur 5',
                onPressed: _isSending
                    ? null
                    : () => setState(() => _note = star),
                icon: Icon(
                  star <= _note ? Icons.star : Icons.star_border,
                  color: AppColors.amber,
                  size: 32,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Envoyer ma note',
          isLoading: _isSending,
          onPressed: _note == 0 ? null : _send,
        ),
      ],
    );
  }
}
