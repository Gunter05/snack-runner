import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/providers/user_provider.dart';
import 'package:snack_runner/services/auth_service.dart';
import 'package:snack_runner/theme/app_colors.dart';

enum DashboardMode { requester, runner }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardMode _mode = DashboardMode.requester;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProvider);
    final courses = ref.watch(courseProvider);
    final myCourses = courses
        .where((course) => course.requesterName == currentUser)
        .toList();
    final activeList = myCourses
        .where(
          (c) =>
              c.status == CourseStatus.acceptee ||
              c.status == CourseStatus.livraison,
        )
        .toList();
    final activeCourse = activeList.isNotEmpty
        ? activeList.first
        : myCourses.isNotEmpty
        ? myCourses.first
        : null;
    final recentCourses = myCourses.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bon retour 👋',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bonjour, $currentUser',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          await AuthService().clearToken();
                          ref.read(authProvider.notifier).logout();
                          ref.read(userProvider.notifier).state = '';
                          context.go('/login');
                        },
                        icon: const Icon(
                          Icons.logout,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.bg3,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.amber,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            currentUser.isNotEmpty
                                ? currentUser[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _ToggleBtn(
                      label: 'Requester',
                      icon: Icons.shopping_bag_outlined,
                      active: _mode == DashboardMode.requester,
                      onTap: () =>
                          setState(() => _mode = DashboardMode.requester),
                    ),
                    _ToggleBtn(
                      label: 'Runner',
                      icon: Icons.directions_run,
                      active: _mode == DashboardMode.runner,
                      onTap: () => setState(() => _mode = DashboardMode.runner),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _mode == DashboardMode.requester
                    ? _RequesterView(
                        activeCourse: activeCourse,
                        recentCourses: recentCourses,
                        totalCourses: myCourses.length,
                      )
                    : const _RunnerView(),
              ),
            ),

            // CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _mode == DashboardMode.requester
                      ? context.push('/nouvelle-course')
                      : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    _mode == DashboardMode.requester
                        ? '+ Nouvelle course'
                        : 'Voir les courses dispo',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),

            // Tab bar
            Container(
              decoration: const BoxDecoration(
                color: AppColors.bg2,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  _TabItem(
                    label: 'Accueil',
                    icon: Icons.home_outlined,
                    active: true,
                    onTap: () {},
                  ),
                  _TabItem(
                    label: 'Mes courses',
                    icon: Icons.list_alt_outlined,
                    active: false,
                    onTap: () => context.go('/courses'),
                  ),
                  _TabItem(
                    label: 'Profil',
                    icon: Icons.person_outline,
                    active: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Requester View ────────────────────────────────────────────────────────────

class _RequesterView extends StatelessWidget {
  final Course? activeCourse;
  final List<Course> recentCourses;
  final int totalCourses;

  const _RequesterView({
    required this.activeCourse,
    required this.recentCourses,
    required this.totalCourses,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Course en cours'),
        const SizedBox(height: 8),
        _ActiveCourseCard(course: activeCourse),
        const SizedBox(height: 16),

        // Stats
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '$totalCourses',
                unit: 'courses',
                label: 'Postées ce mois',
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _StatCard(
                value: '0',
                unit: 'FCFA',
                label: 'Récompenses payées',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const _SectionLabel('Courses récentes'),
        const SizedBox(height: 8),
        if (recentCourses.isEmpty)
          _EmptyState(onTap: () => context.push('/nouvelle-course'))
        else
          ...recentCourses.map((c) => _CourseCard(course: c)),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Runner View ───────────────────────────────────────────────────────────────

class _RunnerView extends StatelessWidget {
  const _RunnerView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Courses disponibles'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: const Center(
            child: Column(
              children: [
                Icon(Icons.directions_run, color: AppColors.amber, size: 36),
                SizedBox(height: 12),
                Text(
                  'Aucune course disponible',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Les nouvelles courses apparaîtront ici',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.black : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.black : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _StatCard({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCourseCard extends StatelessWidget {
  final Course? course;
  const _ActiveCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    if (course == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.radio_button_unchecked,
              color: AppColors.textSecondary,
              size: 16,
            ),
            SizedBox(width: 10),
            Text(
              'Aucune course active pour le moment.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final steps = ['Posté', 'Accepté', 'En route', 'Livré'];
    final stepIndex = course!.status == CourseStatus.enAttente
        ? 0
        : course!.status == CourseStatus.acceptee
        ? 1
        : course!.status == CourseStatus.livraison
        ? 2
        : 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3a2e10), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  course!.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  course!.status.label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Récompense · ${course!.rewardLabel}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (stepIndex + 1) / steps.length,
              backgroundColor: AppColors.bg3,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.amber),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: steps.asMap().entries.map((e) {
              final active = e.key == stepIndex;
              return Text(
                e.value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                  color: active ? AppColors.amber : AppColors.textSecondary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.inbox_outlined,
                color: AppColors.amber,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucune course récente',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Publie ta première course',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  '+ Créer une course',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amber,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  course.status.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            course.rewardLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.amber,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              Icon(
                icon,
                size: 20,
                color: active ? AppColors.amber : AppColors.textSecondary,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active ? AppColors.amber : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
