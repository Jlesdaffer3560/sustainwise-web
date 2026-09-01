import 'package:flutter/material.dart';

/// Design tokens ported 1:1 from the interactive HTML mockup
/// (esg-app-mockup.html) so the real app matches the approved prototype.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFF7F3E8);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1B211D);
  static const inkSoft = Color(0xFF667069);
  static const border = Color(0xFFE5E2D6);

  // A full-saturation "candy" register (was a muted earthy teal/amber) —
  // every `fill` is darkened only as far as needed to clear 4.5:1 against
  // white text, and every `soft` is lightened only as far as needed to
  // keep `inkSoft` body text at 4.5:1+ on top of it, both checked against
  // WCAG's relative-luminance formula rather than eyeballed. Vivid and
  // readable are the same requirement here, not a trade-off.
  static const teal = Color(0xFF008631);
  static const tealDeep = Color(0xFF007029);
  static const tealBright = Color(
    0xFF22C55E,
  ); // decorative only (confetti, icon glyphs) — never sits under text
  static const amber = Color(0xFFA56700);
  static const amberDeep = Color(0xFF704600);

  // The remaining three legs of the E/S/G/Regulation/Finance "content
  // theme" palette — teal already covers environmental, amberDeep already
  // covers finance (gold), so only social, governance, and regulation need
  // dedicated colors. Each verified ≥ 4.5:1 against white for icon/label use.
  static const coralDeep = Color(0xFF8C1F3F); // social
  static const navy = Color(0xFF1B3A66); // governance
  static const violetDeep = Color(0xFF5B2EA6); // regulation

  // The hero banner's own backdrop — deliberately separate from [teal]/
  // [tealDeep] so swapping the hero's mood doesn't also repaint every
  // "Continue" button, the Foundations unit, and every other place the
  // brand teal is used elsewhere in the app.
  static const heroDeep = Color(0xFF052033);
  static const heroMid = Color(0xFF0E6E8C);

  static const success = Color(0xFF2E7D46);
  static const successSoft = Color(0xFFE4F1E7);
  static const danger = Color(0xFFB23A2E);
  static const dangerSoft = Color(0xFFF7E4E1);
  static const accentSoft = Color(0xFFAEEAC4);
  static const amberSoft = Color(0xFFEAD3AE);

  // One accent per learning unit — a genuinely saturated soft tint (not a
  // near-white pastel wash — the whole point is that a *locked* row reads
  // as visibly its own color, not "barely tinted gray"), a fully-saturated
  // fill for completed rows, and a deep shade shared by icons/rims/text.
  // Chosen from genuinely different points on the wheel (green, blue,
  // gold, red, turquoise, pink, lime, violet) rather than variations on
  // one hue family, so units stay tellable-apart even two doors down
  // (green vs. turquoise, gold vs. lime) at a glance, not just in theory.
  static const unitAccents = <UnitAccent>[
    UnitAccent(
      soft: Color(0xFFAEEAC4),
      fill: Color(0xFF008631),
      deep: Color(0xFF007029),
    ), // green — Foundations
    UnitAccent(
      soft: Color(0xFFAED7EA),
      fill: Color(0xFF007CB5),
      deep: Color(0xFF004D70),
    ), // blue — EU Reporting & Diligence
    UnitAccent(
      soft: Color(0xFFEAD3AE),
      fill: Color(0xFFA56700),
      deep: Color(0xFF704600),
    ), // gold — Finance & Taxonomy
    UnitAccent(
      soft: Color(0xFFEAAEAE),
      fill: Color(0xFFE90000),
      deep: Color(0xFF700000),
    ), // red — Reporting Standards
    UnitAccent(
      soft: Color(0xFFAEEAE3),
      fill: Color(0xFF008274),
      deep: Color(0xFF007064),
    ), // turquoise — Climate & Sustainable Finance
    UnitAccent(
      soft: Color(0xFFEAAECC),
      fill: Color(0xFFE20070),
      deep: Color(0xFF700038),
    ), // pink — People & Planet
    UnitAccent(
      soft: Color(0xFFD2EAAE),
      fill: Color(0xFF4E8100),
      deep: Color(0xFF447000),
    ), // lime — Governance & Accountability
    UnitAccent(
      soft: Color(0xFFC0AEEA),
      fill: Color(0xFF834EFF),
      deep: Color(0xFF220070),
    ), // violet — Context & History
  ];

  /// The same 8 hues as [unitAccents], pre-muted for web — fixed values
  /// designed once, rather than the runtime `ColorFiltered` 45%-saturation
  /// pass a review round called "technically a workaround" for a palette
  /// that's "too busy" as-is. Values are that same 45% reduction, computed
  /// ahead of time, so this reads identically wherever it's already
  /// shipped and additionally now applies to Stats/Profile's per-unit
  /// colors, which the runtime filter never covered (it only ever wrapped
  /// Home's module list). Native always uses [unitAccents]; only web ever
  /// reads this list.
  static const unitAccentsWeb = <UnitAccent>[
    UnitAccent(
      soft: Color(0xFFC6E1D0),
      fill: Color(0xFF37734D),
      deep: Color(0xFF2E6040),
    ), // green — Foundations
    UnitAccent(
      soft: Color(0xFFC0D3DB),
      fill: Color(0xFF387089),
      deep: Color(0xFF234555),
    ), // blue — EU Reporting & Diligence
    UnitAccent(
      soft: Color(0xFFDFD4C4),
      fill: Color(0xFF866A3C),
      deep: Color(0xFF5B4829),
    ), // gold — Finance & Taxonomy
    UnitAccent(
      soft: Color(0xFFD0B5B5),
      fill: Color(0xFF841B1B),
      deep: Color(0xFF400D0D),
    ), // red — Reporting Standards
    UnitAccent(
      soft: Color(0xFFC8E3E0),
      fill: Color(0xFF38726C),
      deep: Color(0xFF30625D),
    ), // turquoise — Climate & Sustainable Finance
    UnitAccent(
      soft: Color(0xFFD1B6C4),
      fill: Color(0xFF851F51),
      deep: Color(0xFF420F29),
    ), // pink — People & Planet
    UnitAccent(
      soft: Color(0xFFDAE5CA),
      fill: Color(0xFF5F763C),
      deep: Color(0xFF536634),
    ), // lime — Governance & Accountability
    UnitAccent(
      soft: Color(0xFFBBB2CD),
      fill: Color(0xFF735BAB),
      deep: Color(0xFF18083B),
    ), // violet — Context & History
  ];
}

/// The palette this platform should read unit-accent colors from — native's
/// full-saturation set, or web's pre-muted equivalent.
List<UnitAccent> unitAccentsFor(bool isWeb) =>
    isWeb ? AppColors.unitAccentsWeb : AppColors.unitAccents;

/// A badge tint, a bar fill, and a shared deep shade (badge icon + bar
/// rim) — one triple per learning unit.
class UnitAccent {
  const UnitAccent({
    required this.soft,
    required this.fill,
    required this.deep,
  });

  final Color soft;
  final Color fill;
  final Color deep;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        primary: AppColors.teal,
        secondary: AppColors.amber,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      fontFamily: 'Outfit',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyMedium: TextStyle(color: AppColors.ink),
        bodySmall: TextStyle(color: AppColors.inkSoft),
        labelSmall: TextStyle(color: AppColors.inkSoft, letterSpacing: 0.4),
      ),
      dividerColor: AppColors.border,
    );
  }
}
