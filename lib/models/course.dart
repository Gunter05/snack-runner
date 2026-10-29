import 'package:flutter/material.dart';
import 'package:snack_runner/theme/app_colors.dart';

/// Statut d'une course, aligné sur l'enum Postgres `errand_status`.
enum CourseStatus {
  enAttente('waiting'),
  acceptee('accepted'),
  livraison('delivering'),
  terminee('done'),
  annulee('cancelled');

  const CourseStatus(this.dbValue);

  final String dbValue;

  static CourseStatus fromDb(String value) => values.firstWhere(
    (status) => status.dbValue == value,
    orElse: () => throw FormatException('Statut de course inconnu : $value'),
  );

  /// Transitions autorisées par les politiques RLS de `errands`.
  bool canTransitionTo(CourseStatus next) {
    const allowed = {
      CourseStatus.enAttente: [CourseStatus.acceptee, CourseStatus.annulee],
      CourseStatus.acceptee: [CourseStatus.livraison, CourseStatus.terminee],
      CourseStatus.livraison: [CourseStatus.terminee],
      CourseStatus.terminee: <CourseStatus>[],
      CourseStatus.annulee: <CourseStatus>[],
    };
    return allowed[this]!.contains(next);
  }

  bool get isActive =>
      this == CourseStatus.acceptee || this == CourseStatus.livraison;

  String get label => switch (this) {
    CourseStatus.enAttente => 'En attente',
    CourseStatus.acceptee => 'Acceptée',
    CourseStatus.livraison => 'Livraison',
    CourseStatus.terminee => 'Terminée',
    CourseStatus.annulee => 'Annulée',
  };
}

extension CourseStatusX on CourseStatus {
  Color get badgeBackground {
    switch (this) {
      case CourseStatus.enAttente:
        return AppColors.statusWaitingBg;
      case CourseStatus.acceptee:
        return AppColors.statusAcceptedBg;
      case CourseStatus.livraison:
        return AppColors.statusDeliveringBg;
      case CourseStatus.terminee:
        return AppColors.statusCompletedBg;
      case CourseStatus.annulee:
        return AppColors.statusCancelledBg;
    }
  }

  Color get badgeText {
    switch (this) {
      case CourseStatus.enAttente:
        return AppColors.statusWaitingText;
      case CourseStatus.acceptee:
        return AppColors.statusAcceptedText;
      case CourseStatus.livraison:
        return AppColors.statusDeliveringText;
      case CourseStatus.terminee:
        return AppColors.statusCompletedText;
      case CourseStatus.annulee:
        return AppColors.statusCancelledText;
    }
  }
}

/// Type de course, stocké dans `errands.category`.
enum CourseCategory {
  cafeteria('cafeteria', 'Cafétéria'),
  colis('colis', 'Colis'),
  autre('autre', 'Autre');

  const CourseCategory(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static CourseCategory fromDb(String? value) => values.firstWhere(
    (category) => category.dbValue == value,
    orElse: () => CourseCategory.autre,
  );
}

/// Type de récompense, aligné sur l'enum Postgres `reward_type`.
enum RewardType {
  argent('argent', 'Argent'),
  nourriture('nourriture', 'Nourriture');

  const RewardType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static RewardType fromDb(String value) => values.firstWhere(
    (type) => type.dbValue == value,
    orElse: () => throw FormatException('Type de récompense inconnu : $value'),
  );
}

String formatReward(RewardType type, double? amount, String? description) {
  if (type == RewardType.argent) {
    return '${(amount ?? 0).round()} FCFA';
  }
  final text = description?.trim() ?? '';
  return text.isEmpty ? RewardType.nourriture.label : text;
}

/// Une course (table `errands`) telle que l'utilisateur courant la voit.
class Course {
  final String id;
  final CourseCategory category;
  final String title;
  final String? description;
  final String pickupLocation;
  final String deliveryLocation;
  final RewardType rewardType;
  final double? rewardAmount;
  final String? rewardDescription;
  final CourseStatus status;
  final String requesterId;
  final String requesterName;
  final String? runnerId;
  final String runnerName;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Course({
    required this.id,
    required this.category,
    required this.title,
    this.description,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.rewardType,
    this.rewardAmount,
    this.rewardDescription,
    required this.status,
    required this.requesterId,
    required this.requesterName,
    this.runnerId,
    this.runnerName = '',
    required this.createdAt,
    this.completedAt,
  });

  /// Construit une course depuis une ligne `errands` jointe aux profils
  /// `requester:users(nom)` et `runner:users(nom)`.
  factory Course.fromMap(Map<String, dynamic> map) {
    final requester = map['requester'] as Map<String, dynamic>?;
    final runner = map['runner'] as Map<String, dynamic>?;
    final amount = map['reward_amount'];
    final completedAt = map['completed_at'] as String?;
    return Course(
      id: map['id'] as String,
      category: CourseCategory.fromDb(map['category'] as String?),
      title: map['titre'] as String,
      description: map['description'] as String?,
      pickupLocation: (map['pickup_location'] as String?) ?? '',
      deliveryLocation:
          (map['delivery_location'] as String?) ?? (map['lieu'] as String),
      rewardType: RewardType.fromDb(map['reward_type'] as String),
      rewardAmount: amount == null ? null : (amount as num).toDouble(),
      rewardDescription: map['reward_description'] as String?,
      status: CourseStatus.fromDb(map['status'] as String),
      requesterId: map['requester_id'] as String,
      requesterName: (requester?['nom'] as String?) ?? '',
      runnerId: map['runner_id'] as String?,
      runnerName: (runner?['nom'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: completedAt == null ? null : DateTime.parse(completedAt),
    );
  }

  String get rewardLabel =>
      formatReward(rewardType, rewardAmount, rewardDescription);

  bool isRequester(String? userId) => userId != null && requesterId == userId;

  bool isRunner(String? userId) => userId != null && runnerId == userId;
}

/// Course en cours de saisie, avant publication.
class CourseDraft {
  static const maxTitleLength = 80;

  final CourseCategory category;
  final String description;
  final String pickupLocation;
  final String deliveryLocation;
  final RewardType rewardType;
  final double? rewardAmount;
  final String? rewardDescription;

  const CourseDraft({
    required this.category,
    required this.description,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.rewardType,
    this.rewardAmount,
    this.rewardDescription,
  });

  /// Titre court affiché dans les listes et les notifications push.
  String get title {
    final firstLine = description.trim().split('\n').first.trim();
    if (firstLine.length <= maxTitleLength) return firstLine;
    return '${firstLine.substring(0, maxTitleLength - 1)}…';
  }

  String get rewardLabel =>
      formatReward(rewardType, rewardAmount, rewardDescription);

  Map<String, dynamic> toInsertMap(String requesterId) => {
    'titre': title,
    'description': description.trim(),
    'category': category.dbValue,
    'pickup_location': pickupLocation.trim(),
    'delivery_location': deliveryLocation.trim(),
    // `lieu` est utilisé dans le texte des notifications push.
    'lieu': deliveryLocation.trim(),
    'reward_type': rewardType.dbValue,
    'reward_amount': rewardType == RewardType.argent ? rewardAmount : null,
    'reward_description': rewardType == RewardType.nourriture
        ? rewardDescription?.trim()
        : null,
    'requester_id': requesterId,
  };
}
