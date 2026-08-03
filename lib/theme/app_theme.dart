import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared visual tokens for every mobile screen.
/// Keep new application colours here instead of declaring them in a screen.
abstract final class AppColors {
  static const primary = Color(0xFF0F2646);
  static const primaryDark = Color(0xFF0D2140);
  static const primaryLight = Color(0xFF1E3A8A);
  static const secondary = Color(0xFF3B82F6);
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF3F4F6);
  static const border = Color(0xFFE2E8F0);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  // Legacy screen shades. Names intentionally mirror their hex value so pages
  // can share one source of truth while they use their existing designs.
  static const cFF047857 = Color(0xFF047857); static const cFF059669 = Color(0xFF059669);
  static const cFF0A1120 = Color(0xFF0A1120); static const cFF0F2557 = Color(0xFF0F2557);
  static const cFF0F2647 = Color(0xFF0F2647); static const cFF0F284E = Color(0xFF0F284E);
  static const cFF112D4E = Color(0xFF112D4E); static const cFF120D1B = Color(0xFF120D1B);
  static const cFF161022 = Color(0xFF161022); static const cFF1A3B66 = Color(0xFF1A3B66);
  static const cFF1D4ED8 = Color(0xFF1D4ED8); static const cFF1E293B = Color(0xFF1E293B);
  static const cFF1E3A66 = Color(0xFF1E3A66); static const cFF1F2937 = Color(0xFF1F2937);
  static const cFF24469C = Color(0xFF24469C); static const cFF274A75 = Color(0xFF274A75);
  static const cFF334155 = Color(0xFF334155); static const cFF374151 = Color(0xFF374151);
  static const cFF3B5998 = Color(0xFF3B5998); static const cFF475569 = Color(0xFF475569);
  static const cFF4ADE80 = Color(0xFF4ADE80); static const cFF60A5FA = Color(0xFF60A5FA);
  static const cFF6B7280 = Color(0xFF6B7280); static const cFF818CF8 = Color(0xFF818CF8);
  static const cFF94A3B8 = Color(0xFF94A3B8); static const cFF9A3412 = Color(0xFF9A3412);
  static const cFF9CA3AF = Color(0xFF9CA3AF); static const cFFB91C1C = Color(0xFFB91C1C);
  static const cFFD1FAE5 = Color(0xFFD1FAE5); static const cFFDBEAFE = Color(0xFFDBEAFE);
  static const cFFDC2626 = Color(0xFFDC2626); static const cFFE5E7EB = Color(0xFFE5E7EB);
  static const cFFE63946 = Color(0xFFE63946); static const cFFE8EFFD = Color(0xFFE8EFFD);
  static const cFFEA580C = Color(0xFFEA580C); static const cFFEAB308 = Color(0xFFEAB308);
  static const cFFECF0F3 = Color(0xFFECF0F3); static const cFFEEF2FF = Color(0xFFEEF2FF);
  static const cFFEFF6FF = Color(0xFFEFF6FF); static const cFFF1F5F9 = Color(0xFFF1F5F9);
  static const cFFF6F8FA = Color(0xFFF6F8FA); static const cFFF97316 = Color(0xFFF97316);
  static const cFFFCA5A5 = Color(0xFFFCA5A5); static const cFFFEF2F2 = Color(0xFFFEF2F2);
  static const cFFFF4D4D = Color(0xFFFF4D4D); static const cFFFFEDD5 = Color(0xFFFFEDD5);
  static const cFFFFF7ED = Color(0xFFFFF7ED);
  static const cFF0D2140 = AppColors.primaryDark; static const cFF0F172A = text;
  static const cFF0F2646 = primary; static const cFF10B981 = success;
  static const cFF1E3A8A = AppColors.primaryLight; static const cFF3B82F6 = secondary;
  static const cFF64748B = textMuted; static const cFFE2E8F0 = border;
  static const cFFEF4444 = danger; static const cFFF3F4F6 = surfaceMuted;
  static const cFFF59E0B = warning; static const cFFF8FAFC = background;
  static const cFFFFFFFF = surface;
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.danger,
          onPrimary: Colors.white,
          onSurface: AppColors.text,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.promptTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      );
}
