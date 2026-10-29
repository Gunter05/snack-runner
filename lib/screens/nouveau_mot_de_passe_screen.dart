import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/core/errors.dart';
import 'package:snack_runner/core/validators.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';
import 'package:snack_runner/widgets/common.dart';

/// Ouvert depuis le lien de l'email de réinitialisation : Supabase a déjà
/// ouvert une session temporaire, il reste à choisir le mot de passe.
class NouveauMotDePasseScreen extends ConsumerStatefulWidget {
  const NouveauMotDePasseScreen({super.key});

  @override
  ConsumerState<NouveauMotDePasseScreen> createState() =>
      _NouveauMotDePasseScreenState();
}

class _NouveauMotDePasseScreenState
    extends ConsumerState<NouveauMotDePasseScreen> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool _isLoading = false;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _passwordError = Validators.newPassword(passwordController.text);
      _confirmError = Validators.confirmPassword(
        passwordController.text,
        confirmController.text,
      );
    });
    if (_passwordError != null || _confirmError != null) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(passwordController.text);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Mot de passe modifié.');
      context.go('/dashboard');
    } catch (error) {
      if (mounted) setState(() => _passwordError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _field(TextEditingController controller, String hint, String? error) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint),
        errorText: error,
        filled: true,
        fillColor: AppColors.bg4,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: darkAppBar('Nouveau mot de passe'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisis ton nouveau mot de passe.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              _field(
                passwordController,
                'Nouveau mot de passe',
                _passwordError,
              ),
              const SizedBox(height: 16),
              _field(confirmController, 'Confirmer', _confirmError),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Enregistrer',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
