import 'package:flutter/foundation.dart';
import '../services/device_service.dart';
import 'dart:async';

class DashboardProvider with ChangeNotifier {
  final DeviceService _deviceService = DeviceService();
  
  bool _isInitialized = false;
  Timer? _updateTimer;
  
  bool get isInitialized => _isInitialized;
  
  // Device data getters
  String get deviceId => _deviceService.deviceId;
  int get batteryLevel => _deviceService.batteryLevel;
  String get batteryStatus => _deviceService.getBatteryStatus();
  String get batteryColor => _deviceService.getBatteryColor();
  
  int get signalStrength => _deviceService.getSignalStrength();
  String get signalStatus => _deviceService.getSignalStatus();
  String get signalColor => _deviceService.getSignalColor();
  
  // Speed and tracking getters
  double get currentSpeed => _deviceService.currentSpeed;
  int get currentUpdateInterval => _deviceService.currentUpdateInterval;
  
  // Get display-friendly signal status for UI
  String get signalStatusDisplay {
    final status = _deviceService.getSignalStatus();
    switch (status) {
      case 'strong':
        return 'STRONG';
      case 'weak':
        return 'WEAK';
      case 'poor':
        return 'POOR';
      default:
        return 'POOR';
    }
  }
  
  String get locationStatus => _deviceService.getLocationStatus();
  String get locationColor => _deviceService.getLocationColor();
  String get coordinates => _deviceService.getFormattedCoordinates();
  
  String get sessionStatus => _deviceService.getSessionStatus();
  String get sessionColor => _deviceService.getSessionColor();
  String get lastUpdateTime => _deviceService.lastUpdateTime;
  
  // Wake lock status
  bool get isWakeLockActive => _deviceService.isWakeLockActive;

  // Refresh dashboard data (for background service updates)
  void refreshData() {
    notifyListeners();
    print('DashboardProvider: Data refreshed');
  }
  
  // Initialize dashboard
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Add timeout to prevent hanging
      await _deviceService.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Device service initialization timed out');
        },
      );
      
      // Set up callback for data updates
      _deviceService.setOnDataUpdatedCallback(() {
        refreshData();
      });
      
      _isInitialized = true;
      
      // Start periodic updates
      _startPeriodicUpdates();
      
      notifyListeners();
    } catch (e) {
      print('Error initializing dashboard: $e');
      // Still set as initialized even if there's an error
      // so the UI doesn't stay in loading state forever
      _isInitialized = true;
      
      // Set up callback even if device service failed
      _deviceService.setOnDataUpdatedCallback(() {
        refreshData();
      });
      
      // Start periodic updates even if device service failed
      _startPeriodicUpdates();
      
      notifyListeners();
    }
  }
  
  // Start periodic updates every 5 seconds
  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      notifyListeners();
    });
  }
  
  // Request location permission
  Future<bool> requestLocationPermission() async {
    final granted = await _deviceService.requestLocationPermission();
    notifyListeners();
    return granted;
  }
  
  // Refresh all data
  Future<void> refresh() async {
    // Refresh device data
    await _deviceService.initialize();
    
    // Force send location update to webapp server
    await _deviceService.forceLocationUpdate();
    
    notifyListeners();
  }
  
  // Dispose resources
  @override
  void dispose() {
    _updateTimer?.cancel();
    _deviceService.dispose();
    super.dispose();
  }
}
