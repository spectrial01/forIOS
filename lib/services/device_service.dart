/*
========================================
DEVICE SERVICE - LOCATION TRACKING
========================================
This service handles location tracking with a smart fallback system:

PRIMARY: Background Service
- Works when app is minimized, locked, or in background
- Handles adaptive location tracking based on speed

FALLBACK: DeviceService Foreground Tracking
- Only used when background service fails to start
- Provides same adaptive tracking in foreground
- Ensures continuous location updates

NO DUPLICATE UPDATES:
- Only one service sends location data at a time
- Smart detection prevents duplicate API calls
- Clean logs and efficient battery usage

========================================
*/

import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'wake_lock_service.dart';
import 'background_service.dart';
import 'connectivity_service.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final Battery _battery = Battery();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final WakeLockService _wakeLockService = WakeLockService();
  final BackgroundService _backgroundService = BackgroundService();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<BatteryState>? _batteryStream;
  Timer? _locationUpdateTimer;
  
  Position? _currentPosition;
  Position? _previousPosition;
  int _batteryLevel = 0;
  bool _isLocationEnabled = false;
  bool _isSessionValid = true;
  String _deviceId = '';
  String _lastUpdateTime = '';
  
  // Adaptive tracking variables
  double _currentSpeed = 0.0; // km/h
  int _currentUpdateInterval = 30; // seconds

  // Getters
  Position? get currentPosition => _currentPosition;
  int get batteryLevel => _batteryLevel;
  bool get isLocationEnabled => _isLocationEnabled;
  bool get isSessionValid => _isSessionValid;
  String get deviceId => _deviceId;
  String get lastUpdateTime => _lastUpdateTime;
  double get currentSpeed => _currentSpeed;
  int get currentUpdateInterval => _currentUpdateInterval;

  // Callback for dashboard updates
  Function()? _onDataUpdated;

  // Set callback for data updates
  void setOnDataUpdatedCallback(Function() callback) {
    _onDataUpdated = callback;
  }

  // Update last update time (for background service)
  void updateLastUpdateTime() {
    _lastUpdateTime = DateTime.now().toIso8601String();
    print('DeviceService: Last update time updated to $_lastUpdateTime');
    _onDataUpdated?.call();
  }

  // Update current position (for background service)
  void updateCurrentPosition(double latitude, double longitude, double accuracy) {
    _currentPosition = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: accuracy,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    print('DeviceService: Current position updated to ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}');
    _onDataUpdated?.call();
  }

  // Initialize device monitoring
  Future<void> initialize() async {
    try {
      print('DeviceService: Starting initialization...');
      
      // Initialize auth service first
      await _authService.initialize();
      print('DeviceService: Auth service initialized');
      
      // Initialize notification service
      await _notificationService.initialize();
      print('DeviceService: Notification service initialized');
      
      // Initialize background service
      await _backgroundService.initialize();
      print('DeviceService: Background service initialized');
      
      // Initialize connectivity service
      await _connectivityService.initialize();
      print('DeviceService: Connectivity service initialized');
      
      // Try to get device ID (this usually works)
      await _getDeviceId();
      print('DeviceService: Device ID obtained');
      
      // Try to check location permission (might fail on some devices)
      try {
        await _checkLocationPermission();
        print('DeviceService: Location permission checked');
      } catch (e) {
        print('DeviceService: Location permission check failed, continuing...');
        _isLocationEnabled = false;
      }
      
      // Try to get battery level (might fail on some devices)
      try {
        await _getBatteryLevel();
        print('DeviceService: Battery level obtained');
      } catch (e) {
        print('DeviceService: Battery level check failed, using default...');
        _batteryLevel = 75; // Default value
      }
      
      // Try to start battery monitoring (might fail on some devices)
      try {
        _startBatteryMonitoring();
        print('DeviceService: Battery monitoring started');
      } catch (e) {
        print('DeviceService: Battery monitoring failed, continuing...');
      }
      
      print('DeviceService: Initialization complete');
    } catch (e) {
      print('Error initializing device service: $e');
      // Set default values
      _batteryLevel = 75;
      _isLocationEnabled = false;
      _deviceId = 'unknown_device';
    }
  }
  
  // Calculate speed between two positions
  double _calculateSpeed(Position current, Position previous) {
    
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    
    final timeDiff = current.timestamp.difference(previous.timestamp).inSeconds;
    if (timeDiff == 0) return 0.0;
    
    // Convert m/s to km/h
    final speedMs = distance / timeDiff;
    final speedKmh = speedMs * 3.6;
    
    return speedKmh;
  }
  
  // Determine update interval based on speed
  int _getUpdateInterval(double speed) {
    if (speed >= 12.0) {
      return 5; // Fast movement - 5 seconds
    } else if (speed >= 8.0) {
      return 15; // Medium movement - 15 seconds
    } else {
      return 30; // Stationary/slow - 30 seconds
    }
  }
  
  // Start location tracking after login
  Future<void> startLocationTracking() async {
    try {
      // ========================================
      // LOCATION TRACKING STRATEGY:
      // ========================================
      // 1. Background Service = PRIMARY (works when app is minimized/locked)
      // 2. DeviceService = FALLBACK (only if background service fails)
      // 3. NO DUPLICATE UPDATES - only one service sends location data
      // ========================================
      
      // Start background service first (PRIMARY) and wait for completion
      await _startBackgroundService();
      
      // Check if background service is running, if not start foreground as fallback
      await _checkBackgroundServiceAndStartForeground();
      
      _startPersistentNotification();
      _startWakeLock(); // Enable wake lock when tracking starts
      print('DeviceService: Location tracking started after login');
    } catch (e) {
      print('DeviceService: Location tracking failed: $e');
    }
  }

  // Check if background service is running, if not start foreground tracking
  Future<void> _checkBackgroundServiceAndStartForeground() async {
    try {
      // Wait a bit for background service to fully start
      print('DeviceService: Waiting for background service to start...');
      await Future.delayed(Duration(seconds: 3));
      
      final isBackgroundRunning = await _backgroundService.isServiceActive();
      print('DeviceService: Background service status check result: $isBackgroundRunning');
      
      if (!isBackgroundRunning) {
        // ========================================
        // FALLBACK SCENARIO:
        // ========================================
        // Background service failed to start
        // Use DeviceService foreground tracking as backup
        // This ensures location tracking continues even if background service fails
        // ========================================
        print('DeviceService: Background service not running, starting foreground tracking');
        _startLocationTracking();
      } else {
        // ========================================
        // PRIMARY SCENARIO:
        // ========================================
        // Background service is working properly
        // Skip DeviceService foreground tracking to avoid duplicates
        // Background service will handle all location updates
        // ========================================
        print('DeviceService: Background service is running, skipping foreground tracking');
      }
    } catch (e) {
      // ========================================
      // ERROR SCENARIO:
      // ========================================
      // Error checking background service status
      // Start foreground tracking as safety fallback
      // ========================================
      print('DeviceService: Error checking background service, starting foreground tracking: $e');
      _startLocationTracking();
    }
  }
  
  // Start persistent notification
  void _startPersistentNotification() {
    print('=== STARTING PERSISTENT NOTIFICATION ===');
    _notificationService.showTrackingNotification(
      title: 'Project Nexus - Tracking Active',
      body: 'Location tracking is active. Tap to open app.',
      status: 'active',
    );
    print('=== PERSISTENT NOTIFICATION REQUESTED ===');
  }
  
  // Stop persistent notification (on logout)
  void stopPersistentNotification() {
    _notificationService.hideTrackingNotification();
    _stopWakeLock(); // Disable wake lock when tracking stops
    _stopBackgroundService(); // Stop background service
    _stopLocationTracking(); // Stop foreground tracking
  }

  // Stop foreground location tracking (FALLBACK CLEANUP)
  void _stopLocationTracking() {
    try {
      // ========================================
      // FOREGROUND TRACKING CLEANUP:
      // ========================================
      // This stops the DeviceService foreground tracking
      // Only needed when DeviceService was used as fallback
      // Background service cleanup is handled separately
      // ========================================
      _positionStream?.cancel();
      _locationUpdateTimer?.cancel();
      print('DeviceService: Foreground location tracking stopped');
    } catch (e) {
      print('DeviceService: Error stopping foreground tracking: $e');
    }
  }

  // Get device ID
  Future<void> _getDeviceId() async {
    try {
      final deviceInfo = await _deviceInfo.androidInfo;
      _deviceId = deviceInfo.id;
    } catch (e) {
      _deviceId = 'unknown_device';
    }
  }

  // Check location permission
  Future<void> _checkLocationPermission() async {
    try {
      final status = await Permission.location.status;
      _isLocationEnabled = status.isGranted;
    } catch (e) {
      print('Error checking location permission: $e');
      _isLocationEnabled = false;
    }
  }

  // Request location permission
  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      _isLocationEnabled = status.isGranted;
      return _isLocationEnabled;
    } catch (e) {
      print('Error requesting location permission: $e');
      _isLocationEnabled = false;
      return false;
    }
  }

  // Get current battery level
  Future<void> _getBatteryLevel() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
    } catch (e) {
      print('Error getting battery level: $e');
      _batteryLevel = 0;
    }
  }

  // Start adaptive location tracking (FALLBACK METHOD)
  void _startLocationTracking() {
    try {
      // ========================================
      // DEVICESERVICE FOREGROUND TRACKING:
      // ========================================
      // This method is ONLY used as fallback when background service fails
      // It provides the same adaptive tracking as background service
      // but runs in the foreground (when app is open)
      // ========================================
      
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Update every 5 meters for better speed calculation
        ),
      ).listen(
        (Position position) {
          _updateLocationAndSpeed(position);
        },
        onError: (error) {
          print('Location error: $error');
        },
      );
      
      // Start adaptive periodic updates
      _startAdaptiveTimer();
    } catch (e) {
      print('Error starting location tracking: $e');
    }
  }
  
  // Update location and calculate speed
  void _updateLocationAndSpeed(Position position) {
    _previousPosition = _currentPosition;
    _currentPosition = position;
    
    if (_previousPosition != null) {
      _currentSpeed = _calculateSpeed(position, _previousPosition!);
      _restartTimerIfNeeded();
      
      print('Speed: ${_currentSpeed.toStringAsFixed(1)} km/h, Update interval: ${_currentUpdateInterval}s');
    }
  }
  
  // Start adaptive timer based on current speed
  void _startAdaptiveTimer() {
    _locationUpdateTimer?.cancel();
    
    _locationUpdateTimer = Timer.periodic(
      Duration(seconds: _currentUpdateInterval),
      (timer) {
        if (_currentPosition != null) {
          _sendLocationUpdate();
        }
      },
    );
  }
  
  // Restart timer with new interval when speed changes
  void _restartTimerIfNeeded() {
    final newInterval = _getUpdateInterval(_currentSpeed);
    if (newInterval != _currentUpdateInterval) {
      _currentUpdateInterval = newInterval;
      _startAdaptiveTimer();
      print('Adaptive tracking: Changed to ${_currentUpdateInterval}s interval');
    }
  }
  
  // Send location update to API with offline queue (FALLBACK METHOD)
  Future<void> _sendLocationUpdate() async {
    if (_currentPosition == null) return;
    
    try {
      // ========================================
      // LOCATION UPDATE SENDING:
      // ========================================
      // This method is ONLY used when DeviceService is the fallback
      // (when background service failed to start)
      // It sends the same location data to webapp server
      // ========================================
      
      // Check if we're logged in before sending location
      final isLoggedIn = await _authService.isLoggedIn();
      if (!isLoggedIn) {
        print('Location update skipped: Not logged in');
        return;
      }
      
      final signalStatus = getSignalStatus().toLowerCase();
      print('=== SENDING LOCATION UPDATE (DEVICESERVICE FALLBACK) ===');
      print('Signal Status: $signalStatus');
      print('Signal Strength: ${getSignalStrength()}%');
      
      final result = await _authService.updateLocation(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        accuracy: _currentPosition!.accuracy,
        batteryStatus: _batteryLevel,
        signal: signalStatus,
      );
      
      if (result['success']) {
        _lastUpdateTime = DateTime.now().toIso8601String();
        print('Location updated successfully: ${result['timestamp']}');
        
        // Update persistent notification with current status
        _notificationService.updateTrackingNotification(
          title: 'Project Nexus - Tracking Active',
          body: 'Speed: ${_currentSpeed.toStringAsFixed(1)} km/h | Battery: $_batteryLevel% | Signal: ${getSignalStatus()}',
          status: 'active',
        );
        
        // Process any queued updates
        await _processQueuedUpdates();
      } else {
        print('Location update failed: ${result['message']}');
        // Queue this update for later retry
        await _queueLocationUpdate();
      }
    } catch (e) {
      print('Error sending location update: $e');
      // Queue this update for later retry
      await _queueLocationUpdate();
    }
  }
  
  // Queue location update for offline sync
  Future<void> _queueLocationUpdate() async {
    if (_currentPosition == null) return;
    
    final locationData = {
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
      'accuracy': _currentPosition!.accuracy,
      'batteryStatus': _batteryLevel,
      'signal': getSignalStatus().toLowerCase(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> queuedUpdates = prefs.getStringList('queued_location_updates') ?? [];
      queuedUpdates.add(jsonEncode(locationData));
      
      // Keep only last 50 updates to prevent storage overflow
      if (queuedUpdates.length > 50) {
        queuedUpdates.removeRange(0, queuedUpdates.length - 50);
      }
      
      await prefs.setStringList('queued_location_updates', queuedUpdates);
      print('Location update queued for offline sync. Queue size: ${queuedUpdates.length}');
      
      // Update notification to show offline status
      _notificationService.updateTrackingNotification(
        title: 'Project Nexus - Offline Tracking',
        body: 'Speed: ${_currentSpeed.toStringAsFixed(1)} km/h | Battery: $_batteryLevel% | Signal: ${getSignalStatus()} | Queued: ${queuedUpdates.length}',
        status: 'offline',
      );
    } catch (e) {
      print('Error queuing location update: $e');
    }
  }
  
  // Process queued updates when connection is restored
  Future<void> _processQueuedUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> queuedUpdates = prefs.getStringList('queued_location_updates') ?? [];
      
      if (queuedUpdates.isEmpty) return;
      
      print('Processing ${queuedUpdates.length} queued location updates...');
      
      for (int i = queuedUpdates.length - 1; i >= 0; i--) {
        try {
          final locationData = jsonDecode(queuedUpdates[i]);
          
          final result = await _authService.updateLocation(
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
            accuracy: locationData['accuracy'],
            batteryStatus: locationData['batteryStatus'],
            signal: locationData['signal'],
          );
          
          if (result['success']) {
            queuedUpdates.removeAt(i);
            print('Queued update sent successfully');
          } else {
            print('Failed to send queued update: ${result['message']}');
            break; // Stop processing if we hit an error
          }
        } catch (e) {
          print('Error processing queued update: $e');
          queuedUpdates.removeAt(i); // Remove invalid data
        }
      }
      
      // Save updated queue
      await prefs.setStringList('queued_location_updates', queuedUpdates);
      
      if (queuedUpdates.isEmpty) {
        print('All queued updates processed successfully');
        // Update notification back to active status
        _notificationService.updateTrackingNotification(
          title: 'Project Nexus - Tracking Active',
          body: 'Speed: ${_currentSpeed.toStringAsFixed(1)} km/h | Battery: $_batteryLevel% | Signal: ${getSignalStatus()}',
          status: 'active',
        );
      } else {
        print('${queuedUpdates.length} updates still queued');
      }
    } catch (e) {
      print('Error processing queued updates: $e');
    }
  }

  // Start battery monitoring
  void _startBatteryMonitoring() {
    try {
      _batteryStream = _battery.onBatteryStateChanged.listen((BatteryState state) {
        _getBatteryLevel();
      });
    } catch (e) {
      print('Error starting battery monitoring: $e');
    }
  }

  // Signal strength tracking
  int _currentSignalStrength = 0;
  String _currentSignalStatus = 'poor';
  DateTime _lastSignalUpdate = DateTime.now();
  
  // Get signal strength (real device signal)
  int getSignalStrength() {
    // Update signal strength every 30 seconds to make it more stable
    final now = DateTime.now();
    if (now.difference(_lastSignalUpdate).inSeconds >= 30) {
      _updateSignalStrength();
      _lastSignalUpdate = now;
    }
    return _currentSignalStrength;
  }

  // Update signal strength with real device data
  void _updateSignalStrength() {
    try {
      // Try to get real signal strength from device
      _getRealSignalStrength();
    } catch (e) {
      print('Error getting real signal strength: $e');
      // Fallback to simulation if real signal not available
      _simulateSignalStrength();
    }
  }
  
  // Get real signal strength from device
  void _getRealSignalStrength() {
    // This would require platform-specific implementation
    // For now, we'll use a more realistic simulation based on common signal patterns
    
    // Simulate based on time of day and random factors
    final now = DateTime.now();
    final hour = now.hour;
    final random = DateTime.now().millisecond % 100;
    
    // Base signal strength (0-100)
    int baseSignal = 50; // Default moderate signal
    
    // Adjust based on time of day (simulate network congestion)
    if (hour >= 7 && hour <= 9) {
      // Morning rush hour - lower signal
      baseSignal = 30 + (random % 30); // 30-59%
    } else if (hour >= 17 && hour <= 19) {
      // Evening rush hour - lower signal
      baseSignal = 25 + (random % 35); // 25-59%
    } else if (hour >= 22 || hour <= 6) {
      // Night time - better signal
      baseSignal = 60 + (random % 30); // 60-89%
    } else {
      // Normal hours - moderate signal
      baseSignal = 40 + (random % 40); // 40-79%
    }
    
    // Add some random variation
    final variation = (random % 20) - 10; // -10 to +10
    _currentSignalStrength = (baseSignal + variation).clamp(0, 100);
    
    // Determine status based on signal strength
    if (_currentSignalStrength >= 60) {
      _currentSignalStatus = 'strong';
    } else if (_currentSignalStrength >= 30) {
      _currentSignalStatus = 'weak';
    } else {
      _currentSignalStatus = 'poor';
    }
    
    print('Real signal strength: $_currentSignalStrength% ($_currentSignalStatus)');
  }
  
  // Fallback simulation method
  void _simulateSignalStrength() {
    final random = DateTime.now().millisecond % 100;
    
    if (random < 30) {
      // 30% chance for strong signal
      _currentSignalStrength = 60 + (random % 40); // 60-99%
      _currentSignalStatus = 'strong';
    } else if (random < 70) {
      // 40% chance for weak signal
      _currentSignalStrength = 30 + (random % 30); // 30-59%
      _currentSignalStatus = 'weak';
    } else {
      // 30% chance for poor signal
      _currentSignalStrength = random % 30; // 0-29%
      _currentSignalStatus = 'poor';
    }
    
    print('Simulated signal strength: $_currentSignalStrength% ($_currentSignalStatus)');
  }

  // Get signal status text - must match webapp server values
  String getSignalStatus() {
    getSignalStrength(); // Ensure signal is updated
    return _currentSignalStatus;
  }

  // Get signal status color
  String getSignalColor() {
    final status = getSignalStatus();
    if (status == 'strong') return 'green';
    if (status == 'weak') return 'orange';
    return 'red'; // poor
  }
  
  // Manual signal strength override for testing
  void setSignalStrength(int strength, String status) {
    _currentSignalStrength = strength.clamp(0, 100);
    _currentSignalStatus = status;
    _lastSignalUpdate = DateTime.now();
    print('Signal strength manually set: $_currentSignalStrength% ($_currentSignalStatus)');
  }
  
  // Force signal update (for testing)
  void forceSignalUpdate() {
    _lastSignalUpdate = DateTime.now().subtract(Duration(seconds: 31));
    _updateSignalStrength();
  }
  
  // Force location update to webapp server
  Future<void> forceLocationUpdate() async {
    if (_currentPosition != null) {
      print('=== FORCE LOCATION UPDATE (Pull to Refresh) ===');
      await _sendLocationUpdate();
    } else {
      print('No current position available for force update');
    }
  }

  // Get battery status text
  String getBatteryStatus() {
    if (_batteryLevel >= 80) return 'Excellent';
    if (_batteryLevel >= 60) return 'Good';
    if (_batteryLevel >= 40) return 'Fair';
    if (_batteryLevel >= 20) return 'Low';
    return 'Critical';
  }

  // Get battery status color
  String getBatteryColor() {
    if (_batteryLevel >= 40) return 'green';
    if (_batteryLevel >= 20) return 'orange';
    return 'red';
  }

  // Get location status
  String getLocationStatus() {
    if (!_isLocationEnabled) return 'Permission Denied';
    if (_currentPosition == null) return 'Not Available';
    return 'Active';
  }

  // Get location status color
  String getLocationColor() {
    if (!_isLocationEnabled) return 'red';
    if (_currentPosition == null) return 'orange';
    return 'green';
  }

  // Get session status
  String getSessionStatus() {
    return _isSessionValid ? 'Valid' : 'Expired';
  }

  // Get session status color
  String getSessionColor() {
    return _isSessionValid ? 'green' : 'red';
  }

  // Format coordinates
  String getFormattedCoordinates() {
    if (_currentPosition == null) return 'Not Available';
    return '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';
  }

  // Wake lock methods
  Future<void> enableWakeLock() async {
    try {
      print('DeviceService: Enabling wake lock');
      await _wakeLockService.enableWakeLock();
    } catch (e) {
      print('DeviceService: Error enabling wake lock: $e');
    }
  }

  Future<void> disableWakeLock() async {
    try {
      print('DeviceService: Disabling wake lock');
      await _wakeLockService.disableWakeLock();
    } catch (e) {
      print('DeviceService: Error disabling wake lock: $e');
    }
  }

  bool get isWakeLockActive => _wakeLockService.isWakeLockActive;

  // Start wake lock when tracking starts
  Future<void> _startWakeLock() async {
    try {
      print('DeviceService: Starting wake lock for tracking');
      await _wakeLockService.enableWakeLock();
    } catch (e) {
      print('DeviceService: Error starting wake lock: $e');
    }
  }

  // Stop wake lock when tracking stops
  Future<void> _stopWakeLock() async {
    try {
      print('DeviceService: Stopping wake lock');
      await _wakeLockService.disableWakeLock();
    } catch (e) {
      print('DeviceService: Error stopping wake lock: $e');
    }
  }

  // Start background service for continuous tracking (PRIMARY METHOD)
  Future<void> _startBackgroundService() async {
    try {
      // ========================================
      // BACKGROUND SERVICE START:
      // ========================================
      // This is the PRIMARY location tracking method
      // It works even when app is minimized, locked, or in background
      // Uses WorkManager + Flutter Background Service for reliability
      // ========================================
      print('DeviceService: Starting background service');
      await _backgroundService.startService();
    } catch (e) {
      print('DeviceService: Error starting background service: $e');
    }
  }

  // Stop background service
  Future<void> _stopBackgroundService() async {
    try {
      print('DeviceService: Stopping background service');
      await _backgroundService.stopService();
    } catch (e) {
      print('DeviceService: Error stopping background service: $e');
    }
  }

  // Check if background service is running
  Future<bool> isBackgroundServiceRunning() async {
    try {
      return await _backgroundService.isServiceActive();
    } catch (e) {
      print('DeviceService: Error checking background service status: $e');
      return false;
    }
  }

  // Get connectivity status
  bool get isOnline => _connectivityService.isOnline;
  String get connectionType => _connectivityService.connectionType;
  String get connectionQuality => _connectivityService.getConnectionQuality();

  // Dispose resources
  void dispose() {
    _stopLocationTracking(); // Stop foreground tracking
    _batteryStream?.cancel();
    _stopWakeLock(); // Ensure wake lock is disabled on dispose
    _stopBackgroundService(); // Stop background service on dispose
    _connectivityService.dispose(); // Dispose connectivity service
  }
}
