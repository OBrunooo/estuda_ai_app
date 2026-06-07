import 'package:flutter/material.dart';

/// Tema **apenas escuro**, paleta roxa/violeta alinhada à identidade do app.
class AppTheme {
  AppTheme._();

  /// Fundo principal (midnight purple).
  static const Color midnight = Color(0xFF1E1B2E);

  /// Superfície levemente mais clara (cards / elevação).
  static const Color surfaceElevated = Color(0xFF241D3B);

  /// Cor primária (violeta vibrante).
  static const Color violet = Color(0xFF7B61FF);

  /// Destaque / acento (lavanda-periwinkle).
  static const Color lavender = Color(0xFFA093F2);

  /// Violeta mais escuro (containers, sombras).
  static const Color violetDeep = Color(0xFF5A4CAD);

  /// Lavanda clara para detalhes.
  static const Color periwinkle = Color(0xFFB5A8FF);

  static ThemeData dark() {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: violet,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: violetDeep,
      onPrimaryContainer: Color(0xFFE8DEFF),
      secondary: lavender,
      onSecondary: Color(0xFF16122A),
      secondaryContainer: Color(0xFF3D3558),
      onSecondaryContainer: periwinkle,
      tertiary: periwinkle,
      onTertiary: Color(0xFF1A1530),
      tertiaryContainer: Color(0xFF4A4080),
      onTertiaryContainer: Color(0xFFE8E0FF),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: midnight,
      onSurface: Color(0xFFEAE8F4),
      onSurfaceVariant: Color(0xFFC4BDD4),
      outline: Color(0xFF524A6B),
      outlineVariant: Color(0xFF3D3754),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: lavender,
      onInverseSurface: midnight,
      inversePrimary: violetDeep,
      surfaceTint: violet,
      surfaceContainerHighest: Color(0xFF342E4A),
      surfaceContainerHigh: Color(0xFF2D2842),
      surfaceContainer: Color(0xFF282240),
      surfaceContainerLow: Color(0xFF251F3A),
      surfaceContainerLowest: Color(0xFF161222),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: midnight,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: midnight,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHigh,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: violet,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: violet,
        linearTrackColor: colorScheme.surfaceContainerHigh,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
