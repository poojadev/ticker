import 'package:material_ui/material_ui.dart';

import '../../app/di.dart';
import '../../app/quote_call_stats.dart';
import 'quote_detail_bug.dart';
import 'quote_detail_fix.dart';

/// Which detail page a tile opens. Episode 3's tabs pick one; every other tab
/// gets the correct (fix) version.
enum DetailVariant { bug, fix }

class DetailVariantScope extends InheritedWidget {
  const DetailVariantScope({
    super.key,
    required this.variant,
    required super.child,
  });

  final DetailVariant variant;

  static DetailVariant of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DetailVariantScope>()
          ?.variant ??
      DetailVariant.fix;

  @override
  bool updateShouldNotify(DetailVariantScope oldWidget) =>
      variant != oldWidget.variant;
}

/// Opens the detail screen for [symbol]. Called when a tile is tapped.
void openQuoteDetail(BuildContext context, String symbol) {
  final variant = DetailVariantScope.of(context);
  if (getIt.isRegistered<QuoteCallStats>()) {
    getIt<QuoteCallStats>().recordOpen();
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => variant == DetailVariant.bug
          ? QuoteDetailPageBug(symbol: symbol)
          : QuoteDetailPageFix(symbol: symbol),
    ),
  );
}
