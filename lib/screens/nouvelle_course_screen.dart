import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/providers/user_provider.dart';
import 'package:snack_runner/theme/app_colors.dart';

class NouvelleCourseScreen extends ConsumerStatefulWidget {
  const NouvelleCourseScreen({super.key});

  @override
  ConsumerState<NouvelleCourseScreen> createState() =>
      _NouvelleCourseScreenState();
}

class _NouvelleCourseScreenState extends ConsumerState<NouvelleCourseScreen> {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController deliveryController = TextEditingController();
  final TextEditingController rewardController = TextEditingController();
  String typeSelectionne = 'Cafétéria';
  String? _descriptionError;
  String? _pickupError;
  String? _deliveryError;
  String? _rewardError;

  bool _validate() {
    final reward = double.tryParse(rewardController.text.trim());
    setState(() {
      _descriptionError = descriptionController.text.trim().isEmpty
          ? 'Description requise'
          : null;
      _pickupError = pickupController.text.trim().isEmpty
          ? 'Lieu de retrait requis'
          : null;
      _deliveryError = deliveryController.text.trim().isEmpty
          ? 'Lieu de livraison requis'
          : null;
      _rewardError = rewardController.text.trim().isEmpty
          ? 'Montant requis'
          : (reward == null || reward <= 0)
          ? 'Montant invalide'
          : null;
    });
    return _descriptionError == null &&
        _pickupError == null &&
        _deliveryError == null &&
        _rewardError == null;
  }

  @override
  void dispose() {
    descriptionController.dispose();
    pickupController.dispose();
    deliveryController.dispose();
    rewardController.dispose();
    super.dispose();
  }

  Course _buildCourse() {
    final requester = ref.read(userProvider);
    final rewardValue = double.tryParse(rewardController.text.trim()) ?? 0;

    return Course(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: typeSelectionne,
      title: descriptionController.text.trim(),
      pickupLocation: pickupController.text.trim(),
      deliveryLocation: deliveryController.text.trim(),
      reward: rewardValue,
      rewardType: 'Argent',
      status: CourseStatus.enAttente,
      requesterName: requester,
      runnerName: '',
    );
  }

  void _goToRecap() {
    if (!_validate()) return;
    context.push('/recapitulatif', extra: _buildCourse());
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTypeSelector(
    List<String> options,
    String selected,
    void Function(String) onSelect,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.map((type) {
          final isSelected = selected == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  type,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.black
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? error,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
            filled: true,
            fillColor: error != null
                ? AppColors.danger.withValues(alpha: 0.08)
                : AppColors.bg2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: error != null
                  ? const BorderSide(color: AppColors.danger, width: 1.5)
                  : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: error != null
                  ? const BorderSide(color: AppColors.danger, width: 1.5)
                  : const BorderSide(color: AppColors.border, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 14 : 16,
            ),
            suffixText: suffixText,
            suffixStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              error,
              style: const TextStyle(color: AppColors.danger, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/dashboard'),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Nouvelle course',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('TYPE DE COURSE'),
                    _buildTypeSelector(
                      ['Cafétéria', 'Colis', 'Autre'],
                      typeSelectionne,
                      (v) => setState(() => typeSelectionne = v),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('DÉCRIS TA COMMANDE'),
                    _buildTextField(
                      controller: descriptionController,
                      hint: 'Ex : 2 sandwichs poulet, 1 jus d\'orange...',
                      error: _descriptionError,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('LIEU DE RETRAIT'),
                    _buildTextField(
                      controller: pickupController,
                      hint: 'Ex : Cafét RU B',
                      error: _pickupError,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('LIEU DE LIVRAISON'),
                    _buildTextField(
                      controller: deliveryController,
                      hint: 'Ex : Amphi 3, Bâtiment B',
                      error: _deliveryError,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('RÉCOMPENSE'),
                    _buildTextField(
                      controller: rewardController,
                      hint: '500',
                      error: _rewardError,
                      keyboardType: TextInputType.number,
                      suffixText: 'FCFA',
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToRecap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Voir le récapitulatif →',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
