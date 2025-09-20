import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static const String baseUrl = 'https://asia-southeast1-nexuspolice-13560.cloudfunctions.net';
  static const String setUnitEndpoint = '$baseUrl/setUnit';
  static const String checkStatusEndpoint = '$baseUrl/checkStatus';
  static const String updateLocationEndpoint = '$baseUrl/updateLocation';
  
  String? _apiToken;
  String? _deploymentCode;
  
  // Set API token (this should be provided by your backend)
  void setApiToken(String token) {
    _apiToken = token;
  }
  
  // Login unit with deployment code
  Future<Map<String, dynamic>> login(String deploymentCode) async {
    try {
      print('=== LOGIN DEBUG ===');
      print('API Token: ${_apiToken != null ? "SET" : "NULL"}');
      print('Deployment Code: $deploymentCode');
      print('Login URL: $setUnitEndpoint');
      
      if (_apiToken == null) {
        print('ERROR: API token not set');
        return {
          'success': false,
          'message': 'API token not set. Please contact administrator.',
        };
      }
      
      final requestBody = {
        'deploymentCode': deploymentCode,
        'action': 'login',
      };
      
      print('Login Request Body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse(setUnitEndpoint),
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Login Response Status: ${response.statusCode}');
      print('Login Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _deploymentCode = deploymentCode;
        
        print('SUCCESS: Login successful, deployment code set to: $_deploymentCode');
        
        // Create user object with deployment code
        final user = User(
          id: deploymentCode,
          email: deploymentCode,
          name: 'Unit $deploymentCode',
          deviceId: deploymentCode,
          lastLogin: DateTime.now(),
        );
        
        // Save user data and token locally
        await _saveUserData(user, _apiToken!);
        
        return {
          'success': true,
          'user': user,
          'token': _apiToken,
          'unit_data': data['unit_data'],
        };
      } else {
        final error = jsonDecode(response.body);
        print('ERROR: Login failed - ${response.statusCode} - ${error['message'] ?? 'Unknown error'}');
        return {
          'success': false,
          'message': error['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print('EXCEPTION: Login error - $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  // Logout unit
  Future<Map<String, dynamic>> logout() async {
    try {
      if (_apiToken == null || _deploymentCode == null) {
        return {
          'success': false,
          'message': 'Not logged in',
        };
      }
      
      final response = await http.post(
        Uri.parse(setUnitEndpoint),
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'deploymentCode': _deploymentCode,
          'action': 'logout',
        }),
      );

      if (response.statusCode == 200) {
        _deploymentCode = null;
        await _clearUserData();
        return {
          'success': true,
          'message': 'Logged out successfully',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Logout failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  // Check unit status
  Future<Map<String, dynamic>> checkStatus() async {
    try {
      if (_apiToken == null || _deploymentCode == null) {
        return {
          'success': false,
          'message': 'Not logged in',
        };
      }
      
      final response = await http.post(
        Uri.parse(checkStatusEndpoint),
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'deploymentCode': _deploymentCode,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'isLoggedIn': data['isLoggedIn'] ?? false,
          'loginTime': data['loginTime'],
          'lastActivity': data['lastActivity'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Status check failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
  
  // Update location
  Future<Map<String, dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    required double accuracy,
    required int batteryStatus,
    required String signal,
  }) async {
    try {
      print('=== LOCATION UPDATE UPDATE ===');
      print('API Token: ${_apiToken != null ? "SET" : "NULL"}');
      print('Deployment Code: $_deploymentCode');
      print('Latitude: $latitude');
      print('Longitude: $longitude');
      print('Accuracy: $accuracy');
      print('Battery: $batteryStatus');
      print('Signal: $signal');
      
      if (_apiToken == null || _deploymentCode == null) {
        print('ERROR: Not logged in - Token: ${_apiToken != null}, Deployment: ${_deploymentCode != null}');
        return {
          'success': false,
          'message': 'Not logged in',
        };
      }
      
      final requestBody = {
        'deploymentCode': _deploymentCode,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
        },
        'batteryStatus': batteryStatus,
        'signal': signal,
      };
      
      print('Request URL: $updateLocationEndpoint');
      print('Request Body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse(updateLocationEndpoint),
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('SUCCESS: Location updated to server');
        return {
          'success': true,
          'message': data['message'],
          'timestamp': data['timestamp'],
        };
      } else {
        final error = jsonDecode(response.body);
        print('ERROR: ${response.statusCode} - ${error['message'] ?? 'Unknown error'}');
        return {
          'success': false,
          'message': error['message'] ?? 'Location update failed',
        };
      }
    } catch (e) {
      print('EXCEPTION: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }


  // Save user data locally
  Future<void> _saveUserData(User user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
    await prefs.setString('auth_token', token);
    await prefs.setString('deployment_code', _deploymentCode ?? '');
  }

  // Clear user data
  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove('auth_token');
    await prefs.remove('deployment_code');
  }

  // Get stored user data
  Future<User?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  // Get stored token
  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Get stored deployment code
  Future<String?> getStoredDeploymentCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('deployment_code');
  }

  // Initialize auth service with stored data
  Future<void> initialize() async {
    print('=== AUTH SERVICE INITIALIZE ===');
    final token = await getStoredToken();
    final deploymentCode = await getStoredDeploymentCode();
    
    print('Stored Token: ${token != null ? "FOUND" : "NULL"}');
    print('Stored Deployment Code: $deploymentCode');
    
    if (token != null) {
      _apiToken = token;
      print('API Token set from storage');
    }
    if (deploymentCode != null) {
      _deploymentCode = deploymentCode;
      print('Deployment Code set from storage: $_deploymentCode');
    }
    
    print('Final state - Token: ${_apiToken != null ? "SET" : "NULL"}, Deployment: $_deploymentCode');
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getStoredToken();
    return token != null;
  }
}
