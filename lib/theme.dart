import 'package:flutter/material.dart';

import 'models/issue.dart';

/// Brand and semantic colours. Every text and background pair keeps a
/// contrast ratio of at least 4.5:1 (NFR6).
abstract final class AppColors {
  static const brand = Color(0xFF00695C);
  static const brandDark = Color(0xFF004D43);
  static const background = Color(0xFFF4F6F7);
  static const surface = Colors.white;
  static const ink = Color(0xFF1B1F23);
  static const inkMuted = Color(0xFF59636E);
  static const outline = Color(0xFFDCE1E5);
  static const error = Color(0xFFB3261E);
  static const errorContainer = Color(0xFFFCE8E6);
  static const warningContainer = Color(0xFFFFF4D6);
  static const onWarningContainer = Color(0xFF5C4300);
}

/// Colour and icon for each status, so a status is recognised at a glance
/// and never by colour alone (avoids perceptual errors).
class StatusStyle {
  const StatusStyle(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;

  static StatusStyle of(IssueStatus status) => switch (status) {
        IssueStatus.reported =>
          const StatusStyle(Color(0xFFE6EAEE), Color(0xFF37474F), Icons.flag_outlined),
        IssueStatus.underReview =>
          const StatusStyle(Color(0xFFFFEFC7), Color(0xFF6B4700), Icons.visibility_outlined),
        IssueStatus.inProgress =>
          const StatusStyle(Color(0xFFDDE8FF), Color(0xFF0B4BA8), Icons.construction_outlined),
        IssueStatus.resolved =>
          const StatusStyle(Color(0xFFD8F2E1), Color(0xFF1B6B35), Icons.check_circle_outline),
      };
}

/// Icon and colour for each category, used on cards, tiles and filters.
class CategoryStyle {
  const CategoryStyle(this.background, this.foreground, this.icon, this.examples);

  final Color background;
  final Color foreground;
  final IconData icon;
  final String examples;

  static CategoryStyle of(IssueCategory category) => switch (category) {
        IssueCategory.facilities => const CategoryStyle(Color(0xFFFFE8D9), Color(0xFFA33E00),
            Icons.meeting_room_outlined, 'Rooms, labs, restrooms, cafeteria'),
        IssueCategory.academic => const CategoryStyle(Color(0xFFF1E3F8), Color(0xFF6A1B9A),
            Icons.school_outlined, 'Portal, schedules, registration'),
        IssueCategory.infrastructure => const CategoryStyle(Color(0xFFDDEBFF), Color(0xFF0D47A1),
            Icons.electrical_services_outlined, 'Wi-Fi, power, water, buildings'),
      };
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    surface: AppColors.surface,
  ).copyWith(
    primary: AppColors.brand,
    onPrimary: Colors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    outlineVariant: AppColors.outline,
    error: AppColors.error,
  );

  const radius = BorderRadius.all(Radius.circular(16));
  const fieldRadius = BorderRadius.all(Radius.circular(12));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    // Touch targets of at least 48 x 48 dp (NFR6).
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: TextStyle(color: AppColors.ink, fontSize: 22, fontWeight: FontWeight.w700),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: const OutlineInputBorder(borderRadius: fieldRadius),
      enabledBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: Color(0xFFB9C2CA)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppColors.brand, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 13.5),
      errorMaxLines: 3,
      hintStyle: TextStyle(color: AppColors.inkMuted.withValues(alpha: 0.9)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        side: const BorderSide(color: Color(0xFFB9C2CA)),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: scheme.secondaryContainer,
      side: const BorderSide(color: AppColors.outline),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      extendedTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: scheme.secondaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.ink,
          )),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.inkMuted),
    dividerTheme: const DividerThemeData(color: AppColors.outline, thickness: 1, space: 1),
  );
}
