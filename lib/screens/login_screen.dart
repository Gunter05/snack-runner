import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/core/errors.dart';
import 'package:snack_runner/core/validators.dart';
import 'package:snack_runner/providers/auth_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _emailError = Validators.email(emailController.text);
      _passwordError = Validators.loginPassword(passwordController.text);
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(
            email: emailController.text,
            password: passwordController.text,
          );
      // Le routeur redirige vers le tableau de bord dès que la session
      // est ouverte.
      if (mounted) context.go('/dashboard');
    } catch (error) {
      if (mounted) setState(() => _emailError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Envoie le lien de réinitialisation à l'email saisi. Le message est le
  /// même que le compte existe ou non, pour ne pas révéler les inscrits.
  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();
    final emailError = Validators.email(emailController.text);
    setState(() {
      _emailError = emailError == null
          ? null
          : 'Saisis ton email pour recevoir le lien';
      _passwordError = null;
    });
    if (emailError != null) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordReset(emailController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si un compte existe pour cet email, un lien de '
            'réinitialisation vient d\'être envoyé.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _emailError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background gradient orbs
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.amber.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.amber.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 64),

                      // Logo with glow
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.amber.withValues(alpha: 0.5),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: AppColors.amber.withValues(alpha: 0.2),
                              blurRadius: 64,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'SR',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Title
                      const Text(
                        'SnackRunner',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Les courses du campus, simplifiées.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.45),
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(height: 56),

                      // Email field
                      _buildLabel('EMAIL'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: emailController,
                        hint: 'ton@email.universitaire',
                        hasError: _emailError != null,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      if (_emailError != null) _buildError(_emailError!),

                      const SizedBox(height: 20),

                      // Password field
                      _buildLabel('MOT DE PASSE'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: passwordController,
                        hint: '••••••••',
                        hasError: _passwordError != null,
                        obscure: _obscurePassword,
                        suffix: GestureDetector(
                          onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          child: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ),
                      ),
                      if (_passwordError != null) _buildError(_passwordError!),

                      const SizedBox(height: 12),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _isLoading ? null : _forgotPassword,
                          child: Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(
                              color: AppColors.amber.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Login button
                      _buildLoginButton(),

                      const SizedBox(height: 28),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'ou',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Register button
                      _buildRegisterButton(context),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.35),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool hasError,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? AppColors.danger.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 15,
          ),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: suffix,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: TextStyle(
            color: AppColors.danger.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _signIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: _isLoading
              ? AppColors.amber.withValues(alpha: 0.6)
              : AppColors.amber,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.amber.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text(
                  'Se connecter',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/inscription'),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: Center(
          child: Text(
            'Créer un compte',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
