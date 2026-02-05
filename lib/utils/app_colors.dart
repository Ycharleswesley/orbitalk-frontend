import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Gradient colors
  static const Color gradient1 = Color(0xFF1CCEFC);
  static const Color gradient2 = Color(0xFF322B88);
  static const Color gradient3 = Color(0xFFB64166);
  static const Color gradient4 = Color(0xFFE65E22);
  
  // Primary colors
  static const Color primaryColor = Color(0xFF6B4FA0);
  static const Color primaryDark = Color(0xFF322B88);
  
  // Button colors
  static const Color buttonColor = Color(0xFFB64166);
  static const Color buttonTextColor = Colors.white;
  
  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFE0E0E0);
  static const Color textDark = Colors.black87;
  
  // Background colors
  static const Color backgroundColor = Color(0xFF1A1A2E);
  static const Color cardBackground = Colors.white;
  
  // Dark theme colors
  static const Color darkBackground = Colors.black; // Pure Black
  static const Color darkSurface = Color(0xFF121212); // Standard Material Dark Surface
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkBorder = Color(0xFF2C2C2C);
  
  // Profile Colors
  static const List<Map<String, dynamic>> profileColors = [
    {
      'name': 'Ocean', 
      'id': 0, 
      'color': Color(0xFF02ABE3), // Main (for Avatar)
      'gradient': [Color(0xFF02ABE3), Color(0xFF1B4BAB)], // Top (Light) -> Bottom (Dark)
    },
    {
      'name': 'Sunset', 
      'id': 1, 
      'color': Color(0xFFFF5722), 
      'gradient': [Color(0xFFFF8A65), Color(0xFFD84315)], 
    },
    {
      'name': 'Jungle', 
      'id': 2, 
      'color': Color(0xFF00E676), 
      'gradient': [Color(0xFF69F0AE), Color(0xFF2E7D32)], 
    },
    {
      'name': 'Royal', 
      'id': 3, 
      'color': Color(0xFF651FFF), 
      'gradient': [Color(0xFFB388FF), Color(0xFF311B92)], 
    },
    {
      'name': 'Berry', 
      'id': 4, 
      'color': Color(0xFFE91E63), 
      'gradient': [Color(0xFFF48FB1), Color(0xFF880E4F)], 
    },
  ];

  static List<Color> getGradientColors(int id) {
    return profileColors.firstWhere(
      (element) => element['id'] == id, 
      orElse: () => profileColors[0]
    )['gradient'];
  }

  static Color getColor(int id) {
    return profileColors.firstWhere(
      (element) => element['id'] == id, 
      orElse: () => profileColors[0]
    )['color'];
  }
  static const Color darkTextPrimary = Color(0xFFE8E8E8);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkDivider = Color(0xFF2D2D2D);
  
  // Get gradient with opacity
  static LinearGradient getGradient({double opacity = 0.25}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0.0, 0.25, 0.5, 0.75],
      colors: [
        gradient1.withOpacity(opacity),
        gradient2.withOpacity(opacity),
        gradient3.withOpacity(opacity),
        gradient4.withOpacity(opacity),
      ],
    );
  }
  
  // Full gradient (for splash screen)
  static LinearGradient getFullGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.0, 0.25, 0.5, 0.75],
      colors: [
        gradient1,
        gradient2,
        gradient3,
        gradient4,
      ],
    );
  }

  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: Colors.grey.shade50,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: buttonColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.black87),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: buttonColor,
        brightness: Brightness.dark,
        surface: darkSurface,
        background: darkBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerColor: darkDivider,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextPrimary),
        bodySmall: TextStyle(color: darkTextSecondary),
        titleLarge: TextStyle(color: darkTextPrimary),
        titleMedium: TextStyle(color: darkTextPrimary),
        titleSmall: TextStyle(color: darkTextSecondary),
      ),
    );
  }
}
