import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final DeviceService _deviceService = DeviceService();
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  // Initialize auth state
  Future<void> initializeAuth() async {
    _setLoading(true);
    try {
      await _authService.initialize();
      _user = await _authService.getStoredUser();
      notifyListeners();
    } catch (e) {
      _setError('Failed to initialize authentication');
    } finally {
      _setLoading(false);
    }
  }

  // Set API token (should be called before login)
  void setApiToken(String token) {
    _authService.setApiToken(token);
  }

  // Check if deployment code is available
  Future<Map<String, dynamic>> checkDeploymentCodeAvailability(String deploymentCode) async {
    _setLoading(true);
    _clearError();
    
    try {
      final result = await _authService.checkDeploymentCodeAvailability(deploymentCode);
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error checking deployment code availability: ${e.toString()}',
      };
    } finally {
      _setLoading(false);
    }
  }

  // Login unit with deployment code
  Future<bool> login(String deploymentCode) async {
    _setLoading(true);
    _clearError();
    
    try {
      final result = await _authService.login(deploymentCode);
      
      if (result['success']) {
        _user = result['user'];
        
        // Start location tracking after successful login
        _deviceService.startLocationTracking();
        
        notifyListeners();
        return true;
      } else {
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Logout user
  Future<void> logout() async {
    print('=== AUTH PROVIDER LOGOUT STARTED ===');
    _setLoading(true);
    _clearError();
    
    try {
      // Stop persistent notification first
      _deviceService.stopPersistentNotification();
      print('Notification stopped');
      
      // Call server logout API
      final result = await _authService.logout();
      print('Auth service logout result: $result');
      
      if (result['success']) {
        print('Server logout successful');
        _user = null;
        notifyListeners();
        print('User state cleared and listeners notified');
      } else {
        print('Server logout failed: ${result['message']}');
        _setError('Server logout failed: ${result['message']}');
        // Still clear local data even if server logout fails
        _user = null;
        notifyListeners();
      }
    } catch (e) {
      print('Logout error: $e');
      _setError('Failed to logout: ${e.toString()}');
      // Still clear local data even if logout fails
      _user = null;
      notifyListeners();
    } finally {
      _setLoading(false);
      print('=== AUTH PROVIDER LOGOUT COMPLETED ===');
    }
  }


  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
