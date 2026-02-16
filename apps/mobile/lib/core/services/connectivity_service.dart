import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connectivity state representation.
enum ConnectivityState {
  online,
  offline,
}

/// Wraps connectivity_plus to expose a stream of connectivity state.
///
/// Provides both a current snapshot and a reactive stream for the UI
/// and sync engine to observe connectivity changes.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final StreamController<ConnectivityState> _controller =
      StreamController<ConnectivityState>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectivityState _currentState = ConnectivityState.offline;

  /// Current connectivity state.
  ConnectivityState get currentState => _currentState;

  /// Whether the device is currently online.
  bool get isOnline => _currentState == ConnectivityState.online;

  /// Stream of connectivity state changes.
  Stream<ConnectivityState> get stateStream => _controller.stream;

  /// Initialize the service and start listening for connectivity changes.
  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _updateState(results);

    _subscription = _connectivity.onConnectivityChanged.listen(_updateState);
  }

  void _updateState(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );

    final newState =
        hasConnection ? ConnectivityState.online : ConnectivityState.offline;

    if (newState != _currentState) {
      _currentState = newState;
      _controller.add(newState);
    }
  }

  /// Dispose resources.
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

/// Provider for the connectivity service singleton.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider that streams the current connectivity state.
final connectivityStateProvider = StreamProvider<ConnectivityState>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.stateStream;
});

/// Provider for a simple boolean online check.
final isOnlineProvider = Provider<bool>((ref) {
  final state = ref.watch(connectivityStateProvider);
  return state.when(
    data: (s) => s == ConnectivityState.online,
    loading: () => false,
    error: (_, __) => false,
  );
});
