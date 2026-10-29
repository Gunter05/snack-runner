import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color bg0 = Color(0xFF0E0E10);
  static const Color bg1 = Color(0xFF17171A);
  static const Color bg2 = Color(0xFF1E1E23);
  static const Color bg3 = Color(0xFF26262D);
  static const Color bg4 = Color(0xFF2E2E37);

  static const Color amber = Color(0xFFF0A500);
  static const Color amberDim = Color(0xFFC07800);
  static const Color amberSubtle = Color(0xFF2A2010);
  static const Color amberText = Color(0xFFFFD166);

  static const Color textPrimary = Color(0xFFF2F2F0);
  static const Color textSecondary = Color(0xFF9A9A94);
  static const Color textHint = Color(0xFF5A5A56);

  static const Color success = Color(0xFF22C97A);
  static const Color danger = Color(0xFFE05555);
  static const Color info = Color(0xFF5B9CF6);

  static const Color border = Color(0xFF2E2E37);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  static const Color statusWaitingBg = amberSubtle;
  static const Color statusWaitingText = amberText;
  static const Color statusAcceptedBg = Color(0xFF162E6F);
  static const Color statusAcceptedText = info;
  static const Color statusDeliveringBg = amber;
  static const Color statusDeliveringText = black;
  static const Color statusCompletedBg = Color(0xFF155A47);
  static const Color statusCompletedText = success;
  static const Color statusCancelledBg = Color(0xFF3A1E1E);
  static const Color statusCancelledText = danger;
}
