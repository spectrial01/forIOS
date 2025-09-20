import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService with ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  bool _isOnline = false;
  String _connectionType = 'none';

  // Getters
  List<ConnectivityResult> get connectionStatus => _connectionStatus;
  bool get isOnline => _isOnline;
  String get connectionType => _connectionType;

  // Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      print('ConnectivityService: Initializing...');
      
      // Get initial connectivity status
      _connectionStatus = await _connectivity.checkConnectivity();
      _updateConnectionInfo();
      
      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> result) {
          _connectionStatus = result;
          _updateConnectionInfo();
          notifyListeners();
        },
      );
      
      print('ConnectivityService: Initialized successfully');
    } catch (e) {
      print('ConnectivityService: Initialization failed: $e');
    }
  }

  // Update connection information
  void _updateConnectionInfo() {
    final previousOnline = _isOnline;
    
    if (_connectionStatus.contains(ConnectivityResult.mobile)) {
      _isOnline = true;
      _connectionType = 'mobile';
    } else if (_connectionStatus.contains(ConnectivityResult.wifi)) {
      _isOnline = true;
      _connectionType = 'wifi';
    } else if (_connectionStatus.contains(ConnectivityResult.ethernet)) {
      _isOnline = true;
      _connectionType = 'ethernet';
    } else if (_connectionStatus.contains(ConnectivityResult.vpn)) {
      _isOnline = true;
      _connectionType = 'vpn';
    } else if (_connectionStatus.contains(ConnectivityResult.bluetooth)) {
      _isOnline = true;
      _connectionType = 'bluetooth';
    } else if (_connectionStatus.contains(ConnectivityResult.other)) {
      _isOnline = true;
      _connectionType = 'other';
    } else {
      _isOnline = false;
      _connectionType = 'none';
    }

    // Log connectivity changes
    if (previousOnline != _isOnline) {
      print('ConnectivityService: Connection status changed - Online: $_isOnline, Type: $_connectionType');
    }
  }

  // Check if specific connection type is available
  bool hasConnectionType(ConnectivityResult type) {
    return _connectionStatus.contains(type);
  }

  // Check if mobile data is available
  bool get hasMobileData => hasConnectionType(ConnectivityResult.mobile);

  // Check if WiFi is available
  bool get hasWifi => hasConnectionType(ConnectivityResult.wifi);

  // Check if ethernet is available
  bool get hasEthernet => hasConnectionType(ConnectivityResult.ethernet);

  // Get connection quality based on type
  String getConnectionQuality() {
    if (!_isOnline) return 'offline';
    
    switch (_connectionType) {
      case 'wifi':
        return 'excellent';
      case 'ethernet':
        return 'excellent';
      case 'mobile':
        return 'good';
      case 'vpn':
        return 'good';
      case 'bluetooth':
        return 'fair';
      case 'other':
        return 'fair';
      default:
        return 'poor';
    }
  }

  // Get connection quality color
  String getConnectionQualityColor() {
    final quality = getConnectionQuality();
    switch (quality) {
      case 'excellent':
        return 'green';
      case 'good':
        return 'blue';
      case 'fair':
        return 'orange';
      case 'poor':
        return 'red';
      default:
        return 'red';
    }
  }

  // Force check connectivity
  Future<void> checkConnectivity() async {
    try {
      _connectionStatus = await _connectivity.checkConnectivity();
      _updateConnectionInfo();
      notifyListeners();
      print('ConnectivityService: Manual check - Online: $_isOnline, Type: $_connectionType');
    } catch (e) {
      print('ConnectivityService: Error checking connectivity: $e');
    }
  }

  // Wait for connection to be restored
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isOnline) return true;

    final completer = Completer<bool>();
    StreamSubscription<List<ConnectivityResult>>? subscription;
    Timer? timeoutTimer;

    subscription = _connectivity.onConnectivityChanged.listen((result) {
      _connectionStatus = result;
      _updateConnectionInfo();
      
      if (_isOnline) {
        subscription?.cancel();
        timeoutTimer?.cancel();
        completer.complete(true);
      }
    });

    timeoutTimer = Timer(timeout, () {
      subscription?.cancel();
      completer.complete(false);
    });

    return completer.future;
  }

  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
