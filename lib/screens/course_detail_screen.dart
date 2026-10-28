import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/providers/user_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  bool _isLoading = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _accept(Course course, String userName) async {
    if (userName.isEmpty) {
      _showMessage('Ton profil n\'a pas de nom. Reconnecte-toi et réessaie.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final ok = await ref
          .read(courseProvider.notifier)
          .acceptCourse(course.id, userName);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (ok) {
        context.push('/mission/${course.id}');
      } else {
        _showMessage('Cette course a déjà été prise.');
        context.pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Impossible d\'accepter la course. Vérifie ta connexion.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(courseProvider);
    final userName = ref.watch(userProvider);

    final currentCourse = courses.firstWhere(
      (item) => item.id == widget.course.id,
      orElse: () => widget.course,
    );
    final isRunner =
        userName.isNotEmpty && currentCourse.runnerName == userName;
    final requester = currentCourse.requesterName;

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg0,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Détails de la course'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentCourse.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${currentCourse.category} • ${currentCourse.rewardLabel}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _DetailRow(
              label: 'Point de retrait',
              value: currentCourse.pickupLocation,
            ),
            _DetailRow(
              label: 'Adresse de livraison',
              value: currentCourse.deliveryLocation,
            ),
            _DetailRow(label: 'Demandeur', value: requester),
            _DetailRow(label: 'Statut', value: currentCourse.status.label),
            if (currentCourse.runnerName.isNotEmpty)
              _DetailRow(label: 'Runner', value: currentCourse.runnerName),
            const SizedBox(height: 24),
            if (currentCourse.status == CourseStatus.enAttente &&
                currentCourse.requesterName != userName)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _accept(currentCourse, userName),
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
                          'Accepter cette course',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            if ((currentCourse.status == CourseStatus.acceptee ||
                    currentCourse.status == CourseStatus.livraison) &&
                isRunner)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/mission/${currentCourse.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    side: const BorderSide(color: AppColors.amber, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: const Text(
                    'Voir la mission',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
