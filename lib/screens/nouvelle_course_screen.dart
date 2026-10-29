import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:snack_runner/core/validators.dart';
import 'package:snack_runner/models/course.dart';
import 'package:snack_runner/theme/app_colors.dart';

class NouvelleCourseScreen extends StatefulWidget {
  const NouvelleCourseScreen({super.key});

  @override
  State<NouvelleCourseScreen> createState() => _NouvelleCourseScreenState();
}

class _NouvelleCourseScreenState extends State<NouvelleCourseScreen> {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController deliveryController = TextEditingController();
  final TextEditingController rewardController = TextEditingController();
  final TextEditingController rewardDescriptionController =
      TextEditingController();
  CourseCategory typeSelectionne = CourseCategory.cafeteria;
  RewardType recompenseType = RewardType.argent;
  String? _descriptionError;
  String? _pickupError;
  String? _deliveryError;
  String? _rewardError;

  bool _validate() {
    setState(() {
      _descriptionError = Validators.required(
        descriptionController.text,
        'Description requise',
      );
      _pickupError = Validators.required(
        pickupController.text,
        'Lieu de retrait requis',
      );
      _deliveryError = Validators.required(
        deliveryController.text,
        'Lieu de livraison requis',
      );
      _rewardError = recompenseType == RewardType.argent
          ? Validators.rewardAmount(rewardController.text)
          : Validators.required(
              rewardDescriptionController.text,
              'Décris la récompense',
            );
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
    rewardDescriptionController.dispose();
    super.dispose();
  }

  CourseDraft _buildDraft() {
    final isMoney = recompenseType == RewardType.argent;
    return CourseDraft(
      category: typeSelectionne,
      description: descriptionController.text.trim(),
      pickupLocation: pickupController.text.trim(),
      deliveryLocation: deliveryController.text.trim(),
      rewardType: recompenseType,
      rewardAmount: isMoney ? double.parse(rewardController.text.trim()) : null,
      rewardDescription: isMoney
          ? null
          : rewardDescriptionController.text.trim(),
    );
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
                    onPressed: () => context.pop(),
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
                      [
                        for (final category in CourseCategory.values)
                          category.label,
                      ],
                      typeSelectionne.label,
                      (v) => setState(
                        () => typeSelectionne = CourseCategory.values
                            .firstWhere((category) => category.label == v),
                      ),
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

                    _buildLabel('TYPE DE RÉCOMPENSE'),
                    _buildTypeSelector(
                      [for (final type in RewardType.values) type.label],
                      recompenseType.label,
                      (v) => setState(() {
                        recompenseType = RewardType.values.firstWhere(
                          (type) => type.label == v,
                        );
                        _rewardError = null;
                      }),
                    ),

                    if (recompenseType == RewardType.nourriture) ...[
                      const SizedBox(height: 16),
                      _buildLabel('RÉCOMPENSE PROPOSÉE'),
                      _buildTextField(
                        controller: rewardDescriptionController,
                        hint: 'Ex : un sandwich offert',
                        error: _rewardError,
                      ),
                    ],
                    if (recompenseType == RewardType.argent) ...[
                      const SizedBox(height: 16),
                      _buildLabel('MONTANT'),
                      _buildTextField(
                        controller: rewardController,
                        hint: '500',
                        error: _rewardError,
                        keyboardType: TextInputType.number,
                        suffixText: 'FCFA',
                      ),
                    ],
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
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    if (!_validate()) return;
                    context.push('/recapitulatif', extra: _buildDraft());
                  },
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
