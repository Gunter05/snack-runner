import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snack_runner/models/user_profile.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';
import 'package:snack_runner/widgets/common.dart';

class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      // La redirection vers /login est faite par le routeur.
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      if (mounted) {
        showErrorSnackBar(context, error);
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: darkAppBar('Profil'),
      body: ref
          .watch(profileProvider)
          .when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(profileProvider),
            ),
            data: (profile) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile != null) ...[
                      Text(
                        profile.nom,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      InfoRow(
                        label: 'Mode',
                        value: profile.role == UserRole.runner
                            ? 'Runner'
                            : 'Requester',
                      ),
                      InfoRow(
                        label: 'Note',
                        value: profile.nombreCourses == 0
                            ? 'Pas encore notée'
                            : '${profile.rating.toStringAsFixed(1)} / 5',
                      ),
                      InfoRow(
                        label: 'Avis reçus',
                        value: '${profile.nombreCourses}',
                      ),
                    ],
                    const Spacer(),
                    _isSigningOut
                        ? const LoadingView()
                        : SecondaryButton(
                            label: 'Se déconnecter',
                            color: AppColors.danger,
                            onPressed: _signOut,
                          ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
