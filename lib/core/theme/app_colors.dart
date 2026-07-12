import 'package:flutter/material.dart';

/// Centralized color palette for the VOID LAN "cyber" visual identity.
///
/// All screens must reference these constants instead of hard-coded
/// [Color] values so the palette can be tuned from a single location.
class AppColors {
  const AppColors._();

  // Brand accents
  static const Color voidPurple = Color(0xFF7B2FFF);
  static const Color voidCyan = Color(0xFF00E5FF);
  static const Color voidPink = Color(0xFFFF2E88);
  static const Color voidGreen = Color(0xFF00FFA3);

  // Dark theme surfaces
  static const Color darkBackground = Color(0xFF0A0A0F);
  static const Color darkSurface = Color(0xFF13131C);
  static const Color darkSurfaceAlt = Color(0xFF1B1B27);
  static const Color darkBorder = Color(0xFF2A2A3A);

  // Light theme surfaces
  static const Color lightBackground = Color(0xFFF6F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEFEFF7);
  static const Color lightBorder = Color(0xFFE0E0EC);

  // Status colors
  static const Color statusOnline = Color(0xFF00FFA3);
  static const Color statusOffline = Color(0xFF6B6B7B);
  static const Color statusPending = Color(0xFFFFC53D);
  static const Color statusError = Color(0xFFFF4D5E);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [voidPurple, voidCyan],
  );
}
