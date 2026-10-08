import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF12222F);
  static const cream = Color(0xFFFBF7EF);
  static const lavender = Color(0xFF8B76F0);
  static const lime = Color(0xFFD8F85A);
  static const sky = Color(0xFF8FCDEF);
  static const coral = Color(0xFFF4694F);
  static const slate = Color(0xFF6F8393);
  static const white = Color(0xFFFFFFFF);
  static const clear = Color(0x00000000);

  /// Google's brand colours, for its mark on the sign-in button only.
  static const googleBlue = Color(0xFF4285F4);
  static const googleRed = Color(0xFFEA4335);
  static const googleYellow = Color(0xFFFBBC05);
  static const googleGreen = Color(0xFF34A853);

  /// Bill cards cycle through these per person (section 7.2).
  static const billCardCycle = [lavender, lime, sky, coral];

  /// Text colour that follows the rules in section 2 for a given background.
  static Color onColor(Color background) =>
      (background == lavender || background == coral || background == navy) ? white : navy;
}

class AppOpacity {
  static const addFriend = 0.35;
  static const awayChip = 0.55;
  static const stepNext = 0.30;
  static const scrim = 0.55;
  static const halo = 0.20;
  static const absentMember = 0.45;
}

class AppSpacing {
  static const s4 = 4.0,
      s8 = 8.0,
      s12 = 12.0,
      s16 = 16.0,
      s24 = 24.0,
      s32 = 32.0,
      s40 = 40.0,
      s48 = 48.0;
}

class AppRadius {
  static const sm = 16.0, md = 24.0, lg = 28.0, phone = 44.0, full = 999.0;
  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rLg = BorderRadius.all(Radius.circular(lg));
  static const rFull = BorderRadius.all(Radius.circular(full));
}

class AppSize {
  static const button = 64.0,
      buttonIcon = 40.0,
      backButton = 36.0,
      topBar = 36.0,
      avatarRow = 48.0,
      avatarSettle = 44.0,
      avatarBillCard = 40.0,
      avatarChip = 60.0,
      avatarGroup = 36.0,
      chipWidth = 68.0,
      addFriend = 32.0,
      icon = 28.0,
      navSlot = 48.0,
      navHeight = 64.0,
      progressBar = 14.0,
      stepper = 8.0,
      tabSwitch = 56.0,
      banner = 56.0,
      avatarRing = 4.0,
      avatarRingGroup = 3.0;
}

class AppFonts {
  static const family = 'PlusJakartaSans';

  /// Plus Jakarta Sans has no taka sign, so every style falls back to this bundled font.
  static const bengaliFallback = ['NotoSansBengali'];
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const bold = FontWeight.w700;
  static const extraBold = FontWeight.w800;
}

TextStyle _t(double size, double lineHeight, double letterSpacing, FontWeight w) => TextStyle(
      fontFamily: AppFonts.family,
      fontFamilyFallback: AppFonts.bengaliFallback,
      fontSize: size,
      height: lineHeight / size, // Flutter wants a multiplier
      letterSpacing: letterSpacing,
      fontWeight: w,
      color: AppColors.navy,
    );

class AppType {
  static final celebrate72 = _t(72, 68, -2.88, AppFonts.bold);
  static final hero50 = _t(50, 50, -2, AppFonts.bold);
  static final amount56 = _t(56, 56, -2.24, AppFonts.bold);
  static final amount44 = _t(44, 46, -1.76, AppFonts.bold);
  static final display36 = _t(36, 36, -1.44, AppFonts.bold);
  static final title24 = _t(24, 29, -0.48, AppFonts.medium);
  static final wordmark22 = _t(22, 22, -0.66, AppFonts.extraBold);
  static final heading20 = _t(20, 24, -0.4, AppFonts.medium);
  static final body16 = _t(16, 21, -0.16, AppFonts.medium);
  static final label14 = _t(14, 18, -0.14, AppFonts.medium);
  static final micro12 = _t(12, 16, 0, AppFonts.medium);
  static final micro11 = _t(11, 14, 0, AppFonts.medium);
}

/// Motion constants so widgets do not carry magic numbers.
class AppMotion {
  static const press = Duration(milliseconds: 100);
  static const chip = Duration(milliseconds: 150);
  static const pressScale = 0.96;
  static const maxTextScale = 1.15;
}

/// Widget-level dimensions from the component specs (section 7) so ui code stays literal-free.
class AppDims {
  static const chevronGlyph = 14.0,
      plusGlyph = 14.0,
      actionTileHeight = 176.0,
      actionArrow = 56.0,
      actionArrowStroke = 10.0,
      actionChevronButton = 36.0,
      billRowHeight = 86.0,
      customRowHeight = 80.0,
      checkBadge = 28.0,
      dot = 10.0,
      navActiveCircle = 44.0,
      logoMark = 34.0,
      stepSegmentRadius = 4.0,
      stepGap = 6.0,
      progressRadius = 7.0,
      rateFieldWidth = 56.0,
      rateFieldHeight = 40.0,
      stepperCircle = 32.0,
      groupFrame = 324.0,
      groupFront = 200.0,
      groupSecond = 116.0,
      groupThird = 120.0,
      groupTopInset = 70.0,
      groupOverlap = 8.0,
      selectedChipHeight = 96.0,
      viewfinderHeight = 400.0,
      viewfinderMin = 160.0,
      scanChrome = 400.0,
      chargeAmountWidth = 48.0,
      receiptPaperWidth = 210.0,
      bracket = 40.0,
      bracketStroke = 6.0,
      scanLine = 6.0,
      sheetHandleWidth = 40.0,
      sheetHandleHeight = 6.0,
      sheetTopRadius = 40.0,
      amountFieldWidth = 128.0,
      divider = 2.0,
      activeTick = 28.0,
      recapTile = 96.0,
      codeBoxMax = 52.0,
      codeBoxHeight = 60.0,
      recapTileCompact = 80.0,
      screenTop = 32.0,
      splitBarGap = 2.0,
      coverStep = 5000.0;
  static const groupY = [0.0, 144.0, 204.0];
  static const scrimBlend = 0.55;
}
