import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class InternetService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Function(bool isConnected)? onConnectionChange;

  InternetService({this.onConnectionChange}) {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      // results est une List<ConnectivityResult>
      final bool isConnected = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);

      if (onConnectionChange != null) {
        onConnectionChange!(isConnected);
      }
    });
  }

  Future<bool> isConnected() async {
    List<ConnectivityResult> results = await _connectivity.checkConnectivity();

    bool isConnected = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
    return isConnected;
  }

  void dispose() {
    _subscription?.cancel();
  }
}
