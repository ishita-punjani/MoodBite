import 'package:flutter/material.dart';

/// Colour tokens. Light theme only.
abstract final class AppColors {
  static const primary = Color(0xFFE23744);
  static const onPrimary = Colors.white;
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8F8F8);
  static const textPrimary = Color(0xFF1C1C1C);
  static const textSecondary = Color(0xFF696969);
  static const border = Color(0xFFE0E0E0);
  static const error = Color(0xFFB3261E);
  static const success = Color(0xFF267E3E);
  static const primaryTint = Color(0xFFFDECEE);

  /// Soft card tint per mood. Unknown moods get a stable colour from the list.
  static const _moodTints = {
    'happy': Color(0xFFFFF3CC),
    'stressed': Color(0xFFE6F0FF),
    'sad': Color(0xFFE8EEF7),
    'tired': Color(0xFFEDE7F6),
    'celebratory': Color(0xFFFFE3EC),
    'adventurous': Color(0xFFFFE8D6),
    'romantic': Color(0xFFFCE4EC),
    'energetic': Color(0xFFE2F5E6),
  };
  static const _extraTints = [
    Color(0xFFFFF3CC),
    Color(0xFFE6F0FF),
    Color(0xFFE2F5E6),
    Color(0xFFFFE3EC),
  ];

  static Color moodTint(String moodId) =>
      _moodTints[moodId] ?? _extraTints[moodId.hashCode.abs() % _extraTints.length];

  /// Base colour of the dish placeholder gradient, per dish category.
  static const _categoryTints = {
    'starter': Color(0xFFFFC38A),
    'main': Color(0xFFFFB199),
    'rice': Color(0xFFFFE08A),
    'street_food': Color(0xFFFF9E9E),
    'south_indian': Color(0xFFB9E3A8),
    'breakfast': Color(0xFFFFD98A),
    'bread': Color(0xFFE8C9A0),
    'bakery': Color(0xFFF2C79B),
    'snack': Color(0xFFFFCBA4),
    'pizza_pasta': Color(0xFFFFA98F),
    'salad': Color(0xFFA9E0A9),
    'dessert': Color(0xFFF7B6D2),
    'beverage': Color(0xFF9CD3F2),
    'thali': Color(0xFFFFD08A),
    'seafood': Color(0xFF9ED8E0),
  };

  /// Gradient base for a category; unknown categories use the brand tint.
  static Color categoryTint(String category) => _categoryTints[category] ?? const Color(0xFFFFC2C7);

  /// Dark enough for white text; used for the initials avatar.
  static const avatarPalette = [
    Color(0xFFC62828),
    Color(0xFFAD1457),
    Color(0xFF6A1B9A),
    Color(0xFF283593),
    Color(0xFF00695C),
    Color(0xFF2E7D32),
    Color(0xFFEF6C00),
    Color(0xFF4E342E),
  ];
}

/// Spacing scale used for padding and gaps.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Corner radii.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
}

/// Minimum touch target on every tappable element (Material guideline).
const kMinTouchTarget = 48.0;

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.background,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primaryTint,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.background,
        indicatorColor: AppColors.primaryTint,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, kMinTouchTarget),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(64, kMinTouchTarget)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, kMinTouchTarget)),
          visualDensity: VisualDensity.standard,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(kMinTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    );
  }
}
