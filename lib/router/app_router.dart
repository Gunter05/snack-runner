import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/screens/course_detail_screen.dart';
import 'package:snack_runner/screens/courses_screen.dart';
import 'package:snack_runner/screens/dashboard_screen.dart';
import 'package:snack_runner/screens/fin_mission_screen.dart';
import 'package:snack_runner/screens/inscription_screen.dart';
import 'package:snack_runner/screens/login_screen.dart';
import 'package:snack_runner/screens/mission_screen.dart';
import 'package:snack_runner/screens/nouveau_mot_de_passe_screen.dart';
import 'package:snack_runner/screens/nouvelle_course_screen.dart';
import 'package:snack_runner/screens/profil_screen.dart';
import 'package:snack_runner/screens/recapitulatif_screen.dart';
import 'package:snack_runner/screens/suivi_screen.dart';
import 'package:snack_runner/theme/app_colors.dart';
import 'package:snack_runner/widgets/common.dart';

const _publicLocations = {'/login', '/inscription'};

/// Redirige selon la session Supabase : la source de vérité est la session,
/// pas un indicateur stocké à part.
String? authRedirect({required bool loggedIn, required String location}) {
  final isPublic = _publicLocations.contains(location);
  if (!loggedIn && !isPublic) return '/login';
  if (loggedIn && (isPublic || location == '/')) return '/dashboard';
  return null;
}

/// Rafraîchit le routeur à chaque émission du flux.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _StreamListenable(auth.userIdChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      loggedIn: auth.currentUserId != null,
      location: state.matchedLocation,
    ),
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: darkAppBar('Page introuvable'),
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/dashboard'),
          child: const Text("Retour à l'accueil"),
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/dashboard'),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/inscription',
        name: 'inscription',
        builder: (context, state) => const InscriptionScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/courses',
        name: 'courses',
        builder: (context, state) => const CoursesScreen(),
      ),
      GoRoute(
        // Ouvert par le lien de réinitialisation, qui ouvre une session :
        // sans session (lien expiré), la redirection mène à /login.
        path: '/nouveau-mot-de-passe',
        name: 'nouveau-mot-de-passe',
        builder: (context, state) => const NouveauMotDePasseScreen(),
      ),
      GoRoute(
        path: '/profil',
        name: 'profil',
        builder: (context, state) => const ProfilScreen(),
      ),
      GoRoute(
        path: '/course/:id',
        name: 'course-detail',
        builder: (context, state) =>
            CourseDetailScreen(courseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/nouvelle-course',
        name: 'nouvelle-course',
        builder: (context, state) => const NouvelleCourseScreen(),
      ),
      GoRoute(
        path: '/recapitulatif',
        name: 'recapitulatif',
        // Le brouillon n'existe qu'en mémoire : sans lui (lien direct,
        // restauration), on revient au formulaire.
        redirect: (context, state) =>
            state.extra is CourseDraft ? null : '/nouvelle-course',
        builder: (context, state) =>
            RecapitulatifScreen(draft: state.extra! as CourseDraft),
      ),
      GoRoute(
        path: '/mission/:id',
        name: 'mission',
        builder: (context, state) =>
            MissionScreen(courseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/fin-mission/:id',
        name: 'fin-mission',
        builder: (context, state) =>
            FinMissionScreen(courseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/suivi/:id',
        name: 'suivi',
        builder: (context, state) =>
            SuiviScreen(courseId: state.pathParameters['id']!),
      ),
    ],
  );
});
