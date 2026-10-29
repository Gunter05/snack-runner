import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/models/user_profile.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/providers/course_provider.dart';
import 'package:snack_runner/screens/courses_screen.dart';
import 'package:snack_runner/theme/app_colors.dart';
import 'package:snack_runner/widgets/common.dart';

enum DashboardMode { requester, runner }

/// Chiffres affichés sur le tableau de bord, calculés à partir des courses
/// visibles par l'utilisateur.
class DashboardStats {
  final List<Course> myCourses;
  final Course? activeCourse;
  final int postedThisMonth;
  final double paidRewards;
  final Course? activeMission;
  final int completedMissions;
  final double earnings;
  final List<Course> available;

  const DashboardStats._({
    required this.myCourses,
    required this.activeCourse,
    required this.postedThisMonth,
    required this.paidRewards,
    required this.activeMission,
    required this.completedMissions,
    required this.earnings,
    required this.available,
  });

  factory DashboardStats.from(
    List<Course> courses,
    String? userId, {
    DateTime? now,
  }) {
    final today = (now ?? DateTime.now()).toLocal();
    final myCourses = courses.where((c) => c.isRequester(userId)).toList();
    final myMissions = courses.where((c) => c.isRunner(userId)).toList();

    double moneyOf(Iterable<Course> list) => list
        .where(
          (c) =>
              c.status == CourseStatus.terminee &&
              c.rewardType == RewardType.argent,
        )
        .fold(0, (sum, c) => sum + (c.rewardAmount ?? 0));

    Course? firstWhere(Iterable<Course> list, bool Function(Course) test) {
      for (final course in list) {
        if (test(course)) return course;
      }
      return null;
    }

    return DashboardStats._(
      myCourses: myCourses,
      activeCourse:
          firstWhere(myCourses, (c) => c.status.isActive) ??
          firstWhere(myCourses, (c) => c.status == CourseStatus.enAttente),
      postedThisMonth: myCourses.where((c) {
        final created = c.createdAt.toLocal();
        return created.year == today.year && created.month == today.month;
      }).length,
      paidRewards: moneyOf(myCourses),
      activeMission: firstWhere(myMissions, (c) => c.status.isActive),
      completedMissions: myMissions
          .where((c) => c.status == CourseStatus.terminee)
          .length,
      earnings: moneyOf(myMissions),
      available: availableCourses(courses, userId),
    );
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Choix explicite de l'utilisateur ; à défaut, le rôle du profil.
  DashboardMode? _mode;

  Future<void> _switchMode(DashboardMode mode) async {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    // Seuls les runners reçoivent les push de nouvelles courses : le rôle
    // suit le mode choisi.
    try {
      await ref
          .read(authRepositoryProvider)
          .updateRole(
            mode == DashboardMode.runner ? UserRole.runner : UserRole.requester,
          );
      ref.invalidate(profileProvider);
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider).valueOrNull;
    final profile = ref.watch(profileProvider).valueOrNull;
    final coursesAsync = ref.watch(coursesProvider);
    final stats = DashboardStats.from(coursesAsync.valueOrNull ?? [], userId);
    final mode =
        _mode ??
        (profile?.role == UserRole.runner
            ? DashboardMode.runner
            : DashboardMode.requester);
    final name = profile?.nom ?? '';

    Widget content;
    if (coursesAsync.hasError && !coursesAsync.hasValue) {
      content = ErrorView(
        error: coursesAsync.error!,
        onRetry: () => ref.invalidate(coursesProvider),
      );
    } else if (!coursesAsync.hasValue) {
      content = const LoadingView();
    } else {
      content = RefreshIndicator(
        color: AppColors.amber,
        onRefresh: () => ref.refresh(coursesProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: mode == DashboardMode.requester
              ? _RequesterView(stats: stats)
              : _RunnerView(stats: stats),
        ),
      );
    }

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
                  Expanded(
                    child: Column(
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
                          name.isEmpty ? 'Bonjour' : 'Bonjour, $name',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Se déconnecter',
                        onPressed: _signOut,
                        icon: const Icon(
                          Icons.logout,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/profil'),
                        child: Container(
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
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: AppColors.amber,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
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
                      active: mode == DashboardMode.requester,
                      onTap: () => _switchMode(DashboardMode.requester),
                    ),
                    _ToggleBtn(
                      label: 'Runner',
                      icon: Icons.directions_run,
                      active: mode == DashboardMode.runner,
                      onTap: () => _switchMode(DashboardMode.runner),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(child: content),

            // CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => mode == DashboardMode.requester
                      ? context.push('/nouvelle-course')
                      : context.push('/courses'),
                  icon: Icon(
                    mode == DashboardMode.requester ? Icons.add : Icons.search,
                    size: 18,
                  ),
                  label: Text(
                    mode == DashboardMode.requester
                        ? 'Nouvelle course'
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
                    label: 'Courses',
                    icon: Icons.list_alt_outlined,
                    active: false,
                    onTap: () => context.push('/courses'),
                  ),
                  _TabItem(
                    label: 'Profil',
                    icon: Icons.person_outline,
                    active: false,
                    onTap: () => context.push('/profil'),
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
  final DashboardStats stats;

  const _RequesterView({required this.stats});

  @override
  Widget build(BuildContext context) {
    final activeCourse = stats.activeCourse;
    final recentCourses = stats.myCourses.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Course en cours'),
        const SizedBox(height: 8),
        _ActiveCourseCard(
          course: activeCourse,
          onTap: activeCourse == null
              ? null
              : () => context.push('/suivi/${activeCourse.id}'),
        ),
        const SizedBox(height: 16),

        // Stats
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '${stats.postedThisMonth}',
                unit: 'courses',
                label: 'Postées ce mois',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: stats.paidRewards.round().toString(),
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
          ...recentCourses.map(
            (c) => _CourseCard(
              course: c,
              onTap: () => context.push('/suivi/${c.id}'),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Runner View ───────────────────────────────────────────────────────────────

class _RunnerView extends StatelessWidget {
  final DashboardStats stats;

  const _RunnerView({required this.stats});

  @override
  Widget build(BuildContext context) {
    final mission = stats.activeMission;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Mission en cours'),
        const SizedBox(height: 8),
        _ActiveCourseCard(
          course: mission,
          onTap: mission == null
              ? null
              : () => context.push('/mission/${mission.id}'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '${stats.completedMissions}',
                unit: 'missions',
                label: 'Terminées',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: stats.earnings.round().toString(),
                unit: 'FCFA',
                label: 'Gagnés',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionLabel('Courses disponibles'),
        const SizedBox(height: 8),
        if (stats.available.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: const Column(
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
          )
        else
          ...stats.available
              .take(3)
              .map(
                (c) => _CourseCard(
                  course: c,
                  onTap: () => context.push('/course/${c.id}'),
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
  final VoidCallback? onTap;
  const _ActiveCourseCard({required this.course, this.onTap});

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
            Expanded(
              child: Text(
                'Aucune course active pour le moment.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
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

    final card = Container(
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
    return onTap == null ? card : GestureDetector(onTap: onTap, child: card);
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
  final VoidCallback? onTap;
  const _CourseCard({required this.course, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
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
    return onTap == null ? card : GestureDetector(onTap: onTap, child: card);
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
