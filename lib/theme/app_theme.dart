import 'package:flutter/material.dart';

class AppTheme {
  // New gradient color palette based on design_2.jpg
  static const Color gradientStart = Color(0xFF87CEEB); // Sky blue
  static const Color gradientEnd = Color(0xFFDDA0DD); // Plum/light purple
  static const Color cardBackground = Colors.white;
  static const Color lightCard = Color(0xFFF8F9FA);
  
  // Pastel button colors from design
  static const Color pastelGreen = Color(0xFF90E4C1); // Light mint green
  static const Color pastelRed = Color(0xFFFFB3BA); // Light coral/pink
  
  // Text colors
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF6C7B8A);
  static const Color buttonTextDark = Color(0xFF2C5F41); // Dark green for green button
  
  // Legacy colors for compatibility
  static const Color darkTeal = Color(0xFF2C3E50); // Map to textPrimary
  static const Color lightTeal = Color(0xFF90E4C1); // Map to pastelGreen
  static const Color accent = Color(0xFF6C7B8A); // Map to textSecondary
  
  // App gradient background
  static const LinearGradient appGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primarySwatch: _createMaterialColor(gradientStart),
      scaffoldBackgroundColor: gradientStart, // Will be overridden by gradient
      
      // App Bar Theme - transparent to show gradient
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      
      // Card Theme - clean white cards
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: const EdgeInsets.all(16),
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
  
  // Helper method to create MaterialColor from Color
  static MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
  
  // Custom button styles for the new design
  
  // Green "Add Page" button style
  static ButtonStyle get addPageButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: pastelGreen,
    foregroundColor: buttonTextDark,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    elevation: 4,
    shadowColor: Colors.black.withOpacity(0.2),
    textStyle: const TextStyle(
      fontSize: 18, 
      fontWeight: FontWeight.w600,
    ),
  );
  
  // Red "Generate PDF" button style
  static ButtonStyle get generatePdfButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: pastelRed,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    elevation: 4,
    shadowColor: Colors.black.withOpacity(0.2),
    textStyle: const TextStyle(
      fontSize: 18, 
      fontWeight: FontWeight.w600,
    ),
  );
  
  // Primary scan button for front page - discrete and integrated
  static ButtonStyle get primaryScanButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: Colors.white.withOpacity(0.9),
    foregroundColor: textPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    elevation: 2,
    shadowColor: Colors.black.withOpacity(0.1),
    side: BorderSide(color: textPrimary.withOpacity(0.2), width: 1),
    textStyle: const TextStyle(
      fontSize: 20, 
      fontWeight: FontWeight.w600,
    ),
  );
  
  // Secondary button style
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: cardBackground,
    foregroundColor: textPrimary,
    side: BorderSide(color: textSecondary.withOpacity(0.3), width: 1),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 2,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  );
  
  // Processing buttons style - discrete and integrated with gradient background
  static ButtonStyle get processingButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: Colors.white.withOpacity(0.3),
    foregroundColor: textPrimary,
    padding: const EdgeInsets.all(14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    elevation: 1,
    shadowColor: Colors.black.withOpacity(0.05),
    side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
  );
  
  // Processing buttons style when applied/disabled
  static ButtonStyle get processingButtonAppliedStyle => ElevatedButton.styleFrom(
    backgroundColor: Colors.white.withOpacity(0.6),
    foregroundColor: textPrimary.withOpacity(0.7),
    padding: const EdgeInsets.all(14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    elevation: 0,
    side: BorderSide(color: textSecondary.withOpacity(0.3), width: 1),
  );
}