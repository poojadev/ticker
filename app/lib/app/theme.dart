import 'package:material_ui/material_ui.dart';

class TickerTheme {
  static const up = Color(0xFF2ECC71);
  static const down = Color(0xFFE74C3C);
  static const surface = Color(0xFF12151C);
  static const card = Color(0xFF1A1E27);
  static const muted = Color(0xFF8A93A6);

  /// Tabular figures keep prices from jiggling sideways as digits change.
  static const numbers = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w600,
  );

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF4F7CFF),
    );
    return base.copyWith(
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
