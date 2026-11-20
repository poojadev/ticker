import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../bloc/watchlist_bloc.dart';

/// Everything that isn't the list: the spinner while loading, and the error
/// screen with Retry. Shared by both tabs so their files only differ in the fix.
class WatchlistStatusView extends StatelessWidget {
  const WatchlistStatusView({super.key, required this.state});

  final WatchlistState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == WatchlistStatus.failure) {
      return _ErrorView(message: state.error ?? 'Something went wrong');
    }
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: TickerTheme.muted),
            const SizedBox(height: 12),
            const Text(
              'Can\'t reach the market server.\nIs `dart run bin/server.dart` running?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: TickerTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.read<WatchlistBloc>().add(const WatchlistStarted()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
