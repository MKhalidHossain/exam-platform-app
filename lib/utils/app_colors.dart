import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors (from design images)
  static const Color primaryBlue = Color(0xFF1A52B5); // Dark blue for buttons, logo (from images)
  static const Color primaryBlueDark = Color(0xFF19478D); // Darker blue variant
  static const Color accentBlue = Color(0xFF2F76C4); // Medium blue for links and accents
  static const Color accentCyan = Color(0xFF3489C9); // Lighter blue for accents
  static const Color onboardingBlue = Color(0xFF111111); 
  // Dark blue for onboarding
  
  // Background Colors (matching gradient from images)
  static const Color backgroundGradientStart = Color(0xFFE0F2F7); // Light blue top
  static const Color backgroundGradientEnd = Color(0xFFFFFFFF); // White bottom
  static const Color backgroundLight = Color(0xFFF0F8FF); // Very light blue
  static const Color surface = Color(0xFFFFFFFF); // White for cards/inputs
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121); // Dark grey/black for headings
  static const Color textSecondary = Color(0xFF616161); // Medium grey for body
  static const Color textHint = Color(0xFFAAAAAA); // Light grey for placeholders
  static const Color textLink = Color(0xFF2F76C4); // Blue for links
  static const Color textWhite = Color(0xFFFFFFFF); // White text
  
  // Input Field Colors
  static const Color inputBorder = Color(0xFFB0BEC5); // Light grey border
  static const Color inputBorderLight = Color(0xFFDDEEFF); // Very light blue border
  
  // Status Colors
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  
  // Illustration Colors
  static const Color weaknessRed = Color(0xFFFF0000); // Red for cracks
  static const Color growthOrange = Color(0xFFFF9800); // Orange for arrows
  static const Color inactiveIndicator = Color(0xFFB0C4DE); // Light grey/blue for inactive dots
  
  // Gradient for background
  static LinearGradient get backgroundGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundGradientStart, backgroundGradientEnd],
  );
  
  // Button gradient (for Verify Now button)
  static LinearGradient get buttonGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryBlueDark, primaryBlue],
  );
}
