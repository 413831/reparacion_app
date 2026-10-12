import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized typographic system for "Reparatutti".
/// Uses the "Plus Jakarta Sans" typeface family via google_fonts.
/// Calibrated for maximum readability in outdoor work environments for users aged 30-50.
/// Strict rule: No informative or readable text under 13sp.
class AppTypography {
  AppTypography._();

  /// Modular Typographic Scale Tokens
  static const double displaySmallSize = 26.0;
  static const double titleLargeSize = 20.0;
  static const double titleMediumSize = 17.0;
  static const double bodyLargeSize = 16.0;
  static const double bodyMediumSize = 14.0;
  static const double labelLargeSize = 16.0;
  static const double labelMediumSize = 13.0; // Strict minimum size

  /// Line Height Multipliers
  static const double displaySmallHeight = 1.25;
  static const double titleLargeHeight = 1.30;
  static const double titleMediumHeight = 1.30;
  static const double bodyLargeHeight = 1.45;
  static const double bodyMediumHeight = 1.40;
  static const double labelLargeHeight = 1.20;
  static const double labelMediumHeight = 1.30;

  /// Builds the [TextTheme] for Light Mode using Plus Jakarta Sans
  static TextTheme get lightTextTheme {
    final baseTheme = ThemeData.light().textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(
      baseTheme.copyWith(
        // 26sp, Bold (700), height 1.25 - Títulos de Home ("Pedir trabajo", "Mis Trabajos")
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: displaySmallSize,
          fontWeight: FontWeight.w700,
          height: displaySmallHeight,
          letterSpacing: -0.4,
          color: AppColors.textPrimaryLight,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: displaySmallSize,
          fontWeight: FontWeight.w700,
          height: displaySmallHeight,
          letterSpacing: -0.4,
          color: AppColors.textPrimaryLight,
        ),

        // 20sp, SemiBold (600), height 1.3 - Títulos de tarjetas de servicio y nombres de secciones
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: titleLargeSize,
          fontWeight: FontWeight.w600,
          height: titleLargeHeight,
          letterSpacing: -0.3,
          color: AppColors.textPrimaryLight,
        ),

        // 17sp, SemiBold (600), height 1.3 - Encabezados de chat, nombre de usuario y títulos de modal
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: titleMediumSize,
          fontWeight: FontWeight.w600,
          height: titleMediumHeight,
          letterSpacing: -0.2,
          color: AppColors.textPrimaryLight,
        ),

        // 16sp, Regular (400) / Medium (500), height 1.45 - Descripciones de trabajos, mensajes de chat y formularios
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: bodyLargeSize,
          fontWeight: FontWeight.w400,
          height: bodyLargeHeight,
          letterSpacing: 0.0,
          color: AppColors.textPrimaryLight,
        ),

        // 14sp, Regular (400), height 1.4 - Términos y condiciones, detalles secundarios y subtítulos
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: bodyMediumSize,
          fontWeight: FontWeight.w400,
          height: bodyMediumHeight,
          letterSpacing: 0.1,
          color: AppColors.textSecondaryLight,
        ),

        // 16sp, SemiBold (600), height 1.2 - Botones principales (CTA: "Aceptar Trabajo", "Enviar Ubicación")
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: labelLargeSize,
          fontWeight: FontWeight.w600,
          height: labelLargeHeight,
          letterSpacing: 0.1,
          color: AppColors.buttonTextLight,
        ),

        // 13sp, Medium (500), height 1.3 - Badges de estado (agendado, finalizado), timestamps y scoring
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: labelMediumSize,
          fontWeight: FontWeight.w500,
          height: labelMediumHeight,
          letterSpacing: 0.2,
          color: AppColors.textSecondaryLight,
        ),
      ),
    );
  }

  /// Builds the [TextTheme] for Dark Mode using Plus Jakarta Sans
  static TextTheme get darkTextTheme {
    final baseTheme = ThemeData.dark().textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(
      baseTheme.copyWith(
        // 26sp, Bold (700), height 1.25 - Títulos de Home
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: displaySmallSize,
          fontWeight: FontWeight.w700,
          height: displaySmallHeight,
          letterSpacing: -0.4,
          color: AppColors.textPrimaryDark,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: displaySmallSize,
          fontWeight: FontWeight.w700,
          height: displaySmallHeight,
          letterSpacing: -0.4,
          color: AppColors.textPrimaryDark,
        ),

        // 20sp, SemiBold (600), height 1.3 - Títulos de tarjetas de servicio
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: titleLargeSize,
          fontWeight: FontWeight.w600,
          height: titleLargeHeight,
          letterSpacing: -0.3,
          color: AppColors.textPrimaryDark,
        ),

        // 17sp, SemiBold (600), height 1.3 - Encabezados de chat y modales
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: titleMediumSize,
          fontWeight: FontWeight.w600,
          height: titleMediumHeight,
          letterSpacing: -0.2,
          color: AppColors.textPrimaryDark,
        ),

        // 16sp, Regular (400), height 1.45 - Descripciones y chat
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: bodyLargeSize,
          fontWeight: FontWeight.w400,
          height: bodyLargeHeight,
          letterSpacing: 0.0,
          color: AppColors.textPrimaryDark,
        ),

        // 14sp, Regular (400), height 1.4 - Subtítulos y términos
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: bodyMediumSize,
          fontWeight: FontWeight.w400,
          height: bodyMediumHeight,
          letterSpacing: 0.1,
          color: AppColors.textSecondaryDark,
        ),

        // 16sp, Bold (700) en dark mode sobre mostaza para nitidez en exteriores
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: labelLargeSize,
          fontWeight: FontWeight.w700,
          height: labelLargeHeight,
          letterSpacing: 0.1,
          color: AppColors.buttonTextDark,
        ),

        // 13sp, Medium (500), height 1.3 - Badges de estado y timestamps
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: labelMediumSize,
          fontWeight: FontWeight.w500,
          height: labelMediumHeight,
          letterSpacing: 0.2,
          color: AppColors.textSecondaryDark,
        ),
      ),
    );
  }
}
