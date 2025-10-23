import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring internet connectivity status
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isConnected = true;
  final _connectivityController = StreamController<bool>.broadcast();

  /// Stream that emits true when connected, false when disconnected
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Current connectivity status
  bool get isConnected => _isConnected;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      // Check initial connectivity status
      final result = await _connectivity.checkConnectivity();
      _isConnected = _isConnectionAvailable(result);

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final wasConnected = _isConnected;
          _isConnected = _isConnectionAvailable(results);
          
          // Only emit if status changed
          if (wasConnected != _isConnected) {
            _connectivityController.add(_isConnected);
          }
        },
        onError: (error) {
          // Handle connectivity stream errors silently
        },
      );
    } catch (e) {
      // Handle initialization errors silently
    }
  }

  /// Check if any of the connectivity results indicate an active connection
  bool _isConnectionAvailable(List<ConnectivityResult> results) {
    // If list is empty or contains only 'none', no connection
    if (results.isEmpty) return false;
    
    for (final result in results) {
      if (result != ConnectivityResult.none) {
        return true;
      }
    }
    
    return false;
  }

  /// Manually check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected = _isConnectionAvailable(result);
      return _isConnected;
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}
