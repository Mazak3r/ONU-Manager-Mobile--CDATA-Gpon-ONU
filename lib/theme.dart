import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const bgTop       = Color(0xFFF0E5FB);   // soft lavender
  static const bgMid       = Color(0xFFFBE5F5);   // pinkish
  static const bgBottom    = Color(0xFFE5EDFB);   // pale blue

  // Accents
  static const primary     = Color(0xFF9B7BEA);   // purple
  static const primaryDeep = Color(0xFF6B4FBF);
  static const pink        = Color(0xFFF5C8E0);
  static const blue        = Color(0xFFB8D4F0);
  static const mint        = Color(0xFFB8E6D9);

  // Text
  static const textDark    = Color(0xFF2D2B55);
  static const textMid     = Color(0xFF6E6B94);
  static const textLight   = Color(0xFF9C99BF);

  // Status
  static const ok          = Color(0xFF4CAF50);
  static const warn        = Color(0xFFFFC107);
  static const bad         = Color(0xFFF44336);
  static const hot         = Color(0xFFFF9800);

  // Card surface
  static const card        = Color(0xFFFFFFFF);
  static const cardMuted   = Color(0xFFF5F1FC);
}

class AppGradients {
  static const background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.bgTop, AppColors.bgMid, AppColors.bgBottom],
  );

  static const primaryButton = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primary, AppColors.primaryDeep],
  );

  static const purplePink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC6A8F5), Color(0xFFF5B8DC)],
  );

  static const blueMint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB8D4F0), Color(0xFFB8E6D9)],
  );

  static const lavenderSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE4D4FA), Color(0xFFF3E4FB)],
  );
}

class AppText {
  static const h1 = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    height: 1.15,
    letterSpacing: -0.5,
  );

  static const h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    letterSpacing: -0.3,
  );

  static const h3 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  static const body = TextStyle(
    fontSize: 14,
    color: AppColors.textMid,
    height: 1.35,
  );

  static const small = TextStyle(
    fontSize: 12,
    color: AppColors.textLight,
  );

  static const tiny = TextStyle(
    fontSize: 10.5,
    color: AppColors.textLight,
    letterSpacing: 0.6,
  );

  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMid,
    letterSpacing: 0.8,
  );

  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    color: AppColors.textDark,
  );
}

class AppRadius {
  static const card = 24.0;
  static const pill = 100.0;
  static const tile = 20.0;
}

class AppShadow {
  static const soft = [
    BoxShadow(
      color: Color(0x149B7BEA),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const card = [
    BoxShadow(
      color: Color(0x0F2D2B55),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];
}
