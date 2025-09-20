import 'package:wakelock_plus/wakelock_plus.dart';

class WakeLockService {
  static final WakeLockService _instance = WakeLockService._internal();
  factory WakeLockService() => _instance;
  WakeLockService._internal();

  bool _isWakeLockActive = false;

  bool get isWakeLockActive => _isWakeLockActive;

  // Enable wake lock to prevent screen from turning off
  Future<void> enableWakeLock() async {
    try {
      print('=== ENABLING WAKE LOCK ===');
      
      if (_isWakeLockActive) {
        print('Wake lock already active');
        return;
      }

      await WakelockPlus.enable();
      _isWakeLockActive = true;
      
      print('Wake lock enabled successfully');
    } catch (e) {
      print('Error enabling wake lock: $e');
    }
  }

  // Disable wake lock to allow screen to turn off normally
  Future<void> disableWakeLock() async {
    try {
      print('=== DISABLING WAKE LOCK ===');
      
      if (!_isWakeLockActive) {
        print('Wake lock already inactive');
        return;
      }

      await WakelockPlus.disable();
      _isWakeLockActive = false;
      
      print('Wake lock disabled successfully');
    } catch (e) {
      print('Error disabling wake lock: $e');
    }
  }

  // Check if wake lock is currently enabled
  Future<bool> isEnabled() async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      print('Error checking wake lock status: $e');
      return false;
    }
  }

  // Toggle wake lock on/off
  Future<void> toggleWakeLock() async {
    if (_isWakeLockActive) {
      await disableWakeLock();
    } else {
      await enableWakeLock();
    }
  }

  // Force enable wake lock (useful for debugging)
  Future<void> forceEnable() async {
    try {
      print('=== FORCE ENABLING WAKE LOCK ===');
      await WakelockPlus.enable();
      _isWakeLockActive = true;
      print('Wake lock force enabled');
    } catch (e) {
      print('Error force enabling wake lock: $e');
    }
  }

  // Force disable wake lock (useful for debugging)
  Future<void> forceDisable() async {
    try {
      print('=== FORCE DISABLING WAKE LOCK ===');
      await WakelockPlus.disable();
      _isWakeLockActive = false;
      print('Wake lock force disabled');
    } catch (e) {
      print('Error force disabling wake lock: $e');
    }
  }
}
