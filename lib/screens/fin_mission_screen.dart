import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/providers/user_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';

class FinMissionScreen extends ConsumerStatefulWidget {
  final String courseId;

  const FinMissionScreen({super.key, required this.courseId});

  @override
  ConsumerState<FinMissionScreen> createState() => _FinMissionScreenState();
}

class _FinMissionScreenState extends ConsumerState<FinMissionScreen> {
  bool _isLoading = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _validate(Course course, String userName) async {
    if (course.status == CourseStatus.terminee) {
      context.go('/dashboard');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final ok = await ref
          .read(courseProvider.notifier)
          .completeCourse(course.id, userName);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (ok) {
        context.go('/dashboard');
      } else {
        _showMessage('Impossible de valider la livraison.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Erreur réseau. Vérifie ta connexion et réessaie.');
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
        title: const Text('Fin de mission'),
      ),
      body: course == null
          ? const Center(child: Text('Course introuvable.'))
          : _buildContent(course, userName),
    );
  }

  Widget _buildContent(Course course, String userName) {
    final isCompleted = course.status == CourseStatus.terminee;
    final isRunner = userName.isNotEmpty && course.runnerName == userName;
    final canValidate = isCompleted || isRunner;
    final title = isCompleted ? 'Mission terminée' : 'Terminer la livraison';
    final buttonLabel = isCompleted
        ? "Retour à l'accueil"
        : 'Valider la livraison';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
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
          _RewardCard(label: course.rewardLabel),
          const Spacer(),
          if (!canValidate)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Seul le runner de cette course peut valider la livraison.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isLoading || !canValidate)
                  ? null
                  : () => _validate(course, userName),
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
                  : Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final String label;

  const _RewardCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.amber,
            ),
          ),
        ],
      ),
    );
  }
}
