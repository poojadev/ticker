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
        // Off for now: in waste_lens 0.1.1 the overlay is notified while
        // Flutter is still building, so every dead rebuild throws
        // "setState() or markNeedsBuild() called during build" in the
        // console. Fixed in 0.1.2. Turn this back on after upgrading.
        // DeadRebuildProbe still flashes tiles amber, and the report
        // button still prints the dead-rebuild count.
        overlay: false,
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
