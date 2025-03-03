import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class InternetService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  Function(bool isConnected)? onConnectionChange;

  InternetService({this.onConnectionChange}) {
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      bool isConnected = result != ConnectivityResult.none;
      if (onConnectionChange != null) {
        onConnectionChange!(isConnected);
      }
    });
  }

  Future<bool> isConnected() async {
    ConnectivityResult result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  void dispose() {
    _subscription?.cancel();
  }
}
