import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/providers/user_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';

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
      final ok = await ref
          .read(courseProvider.notifier)
          .startDelivery(course.id);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de démarrer la livraison.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur réseau. Vérifie ta connexion et réessaie.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(courseProvider);
    final userName = ref.watch(userProvider);

    Course? course;
    for (final c in courses) {
      if (c.id == widget.courseId) {
        course = c;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg0,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Mission'),
      ),
      body: course == null
          ? const Center(child: Text('Course introuvable.'))
          : _buildContent(context, course, userName),
    );
  }

  Widget _buildContent(BuildContext context, Course course, String userName) {
    final isRunner = userName.isNotEmpty && course.runnerName == userName;
    final canStart = course.status == CourseStatus.acceptee && isRunner;
    final canComplete = course.status == CourseStatus.livraison && isRunner;

    return Padding(
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
          _InfoRow(label: 'Retrait', value: course.pickupLocation),
          _InfoRow(label: 'Livraison', value: course.deliveryLocation),
          _InfoRow(label: 'Statut', value: course.status.label),
          if (course.runnerName.isNotEmpty)
            _InfoRow(label: 'Runner', value: course.runnerName),
          const Spacer(),
          if (!isRunner)
            const Text(
              'Tu n\'es pas le runner de cette course.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          if (canStart)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _startDelivery(course),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.white,
                          ),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Démarrer la livraison',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          if (canComplete)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/fin-mission/${course.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  'Terminer la mission',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
