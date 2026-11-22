import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/models/quote_detail.dart';
import '../../data/repository/market_repository.dart';

enum QuoteDetailStatus { loading, loaded, failure }

final class QuoteDetailState extends Equatable {
  const QuoteDetailState({
    this.status = QuoteDetailStatus.loading,
    this.detail,
    this.error,
  });

  final QuoteDetailStatus status;
  final QuoteDetail? detail;
  final String? error;

  @override
  List<Object?> get props => [status, detail, error];
}

/// EPISODE 3, THE FIX: the ONE owner of a symbol's quote on the detail screen.
/// It fetches once; every widget on the page reads from it.
class QuoteDetailCubit extends Cubit<QuoteDetailState> {
  QuoteDetailCubit(this._repo) : super(const QuoteDetailState());

  final MarketRepository _repo;

  Future<void> load(String symbol) async {
    emit(const QuoteDetailState());
    try {
      final detail = await _repo.quote(symbol);
      emit(QuoteDetailState(status: QuoteDetailStatus.loaded, detail: detail));
    } catch (e) {
      emit(QuoteDetailState(status: QuoteDetailStatus.failure, error: '$e'));
    }
  }
}
