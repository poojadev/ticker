import 'package:material_ui/material_ui.dart';
import 'package:waste_lens/waste_lens.dart';

import 'app/di.dart';
import 'app/theme.dart';
import 'features/watchlist/view/watchlist_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(
    // One wrap, whole app instrumented. In release builds WasteLens returns
    // its child untouched — zero overhead.
    const WasteLens(
      config: WasteLensConfig(
        rebuilds: true,
        leaks: true,
        memory: true,
        overlay: true,
      ),
      child: TickerApp(),
    ),
  );
}

class TickerApp extends StatelessWidget {
  const TickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ticker',
      debugShowCheckedModeBanner: false,
      theme: TickerTheme.dark(),
      home: const WatchlistPage(),
    );
  }
}
