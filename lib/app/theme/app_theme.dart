import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const small = 8.0;
  static const medium = 16.0;
  static const page = 24.0;
  static const large = 32.0;
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF141615) : const Color(0xFFFAFAF8);
    final foreground = dark ? const Color(0xFFF5F5F2) : const Color(0xFF191919);
    final secondary = dark ? const Color(0xFFA3A5A1) : const Color(0xFF6C706A);
    final divider = dark ? const Color(0xFF303330) : const Color(0xFFEAEAE7);
    final accent = dark ? const Color(0xFF91B9AA) : const Color(0xFF315C50);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: background,
          surface: background,
          onSurface: foreground,
          onSurfaceVariant: secondary,
          outlineVariant: divider,
          surfaceContainerHighest: divider,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      dividerColor: divider,
      textTheme: base.textTheme.copyWith(
        headlineLarge: TextStyle(
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          color: foreground,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: secondary),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: secondary),
        labelSmall: TextStyle(
          fontSize: 11,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? accent : secondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? accent : secondary,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      inputDecorationTheme: InputDecorationThemeData(
        filled: false,
        contentPadding: const EdgeInsets.all(AppSpacing.medium),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.small),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.small),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.small),
          borderSide: BorderSide(color: accent),
        ),
      ),
    );
  }
}
