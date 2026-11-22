import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:waste_lens/waste_lens.dart';

import '../data/api/market_api.dart';
import '../data/api/price_stream.dart';
import '../data/repository/market_repository.dart';
import '../features/watchlist/bloc/watchlist_bloc.dart';
import 'config.dart';
import 'quote_call_stats.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  // Lazy on purpose: Dio is first resolved when the first Bloc is created,
  // which happens *inside* the WasteLens widget — so WasteLens.current exists
  // and the interceptor can report to the overlay.
  //
  // QuoteCallStats owns the RedundantCallInterceptor (so Episode 3 can switch
  // coalescing on and off) and counts GET /quote/ traffic for the AppBar.
  getIt.registerLazySingleton<QuoteCallStats>(
    () => QuoteCallStats(bus: WasteLens.current?.bus),
  );
  getIt.registerLazySingleton<Dio>(
    () => Dio(
      BaseOptions(
        baseUrl: AppConfig.httpBase,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    )..interceptors.add(getIt<QuoteCallStats>().interceptor),
  );

  getIt
    ..registerLazySingleton<MarketApi>(() => MarketApi(getIt<Dio>()))
    ..registerLazySingleton<PriceStream>(() => PriceStream(AppConfig.streamUri))
    ..registerLazySingleton<MarketRepository>(
      () => MarketRepository(getIt<MarketApi>(), getIt<PriceStream>()),
    )
    ..registerFactory<WatchlistBloc>(
      () => WatchlistBloc(getIt<MarketRepository>()),
    );
}
