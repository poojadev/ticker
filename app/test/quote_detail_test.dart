import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ticker/app/di.dart';
import 'package:ticker/data/models/quote_detail.dart';
import 'package:ticker/data/repository/market_repository.dart';
import 'package:ticker/features/quote_detail/quote_detail_bug.dart';
import 'package:ticker/features/quote_detail/quote_detail_cubit.dart';
import 'package:ticker/features/quote_detail/quote_detail_fix.dart';

class _MockRepo extends Mock implements MarketRepository {}

/// Episode 3: who owns the fetch decides how many requests one screen sends.
void main() {
  const nova = QuoteDetail(
    symbol: 'NOVA',
    name: 'Nova Robotics',
    price: 92.44,
    changePct: 1.2,
    open: 91.0,
    high: 93.1,
    low: 90.5,
    volume: 120000,
  );

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.quote('NOVA')).thenAnswer((_) async => nova);
    getIt.registerSingleton<MarketRepository>(repo);
  });

  tearDown(() => getIt.reset());

  Future<void> open(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  testWidgets('bug page: two widgets each fetch the quote (2 calls)',
      (tester) async {
    await open(tester, const QuoteDetailPageBug(symbol: 'NOVA'));
    verify(() => repo.quote('NOVA')).called(2);
    expect(find.text('92.44'), findsOneWidget); // PriceHeader
    expect(find.text('KEY STATS'), findsOneWidget); // KeyStatsCard
  });

  testWidgets('fix page: one cubit fetches once (1 call)', (tester) async {
    await open(tester, const QuoteDetailPageFix(symbol: 'NOVA'));
    verify(() => repo.quote('NOVA')).called(1);
    expect(find.text('92.44'), findsOneWidget);
    expect(find.text('KEY STATS'), findsOneWidget);
  });

  blocTest<QuoteDetailCubit, QuoteDetailState>(
    'QuoteDetailCubit: loading -> loaded',
    build: () => QuoteDetailCubit(repo),
    act: (cubit) => cubit.load('NOVA'),
    expect: () => const [
      QuoteDetailState(),
      QuoteDetailState(status: QuoteDetailStatus.loaded, detail: nova),
    ],
    verify: (_) => verify(() => repo.quote('NOVA')).called(1),
  );
}
