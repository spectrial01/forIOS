import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'login_screen.dart';
import '../services/notification_service.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with WidgetsBindingObserver {
  bool _isLocationGranted = false;
  bool _isNotificationGranted = false;
  bool _isCameraGranted = false;
  bool _isBatteryOptimizationDisabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check permissions when user returns to app
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check location permission
      final locationStatus = await Permission.location.status;
      _isLocationGranted = locationStatus.isGranted;

      // Check notification permission using NotificationService
      final notificationService = NotificationService();
      _isNotificationGranted = await notificationService.isNotificationPermissionGranted();

      // Check camera permission
      final cameraStatus = await Permission.camera.status;
      _isCameraGranted = cameraStatus.isGranted;

      // Check battery optimization (Android only)
      if (Platform.isAndroid) {
        _isBatteryOptimizationDisabled = await _checkBatteryOptimizationDisabled();
      } else {
        _isBatteryOptimizationDisabled = true; // iOS doesn't have this
      }

      setState(() {
        _isLoading = false;
      });
      
      // Check if all permissions are now granted and open location settings
      _checkAllPermissionsAndProceed();
    } catch (e) {
      print('Error checking permissions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkBatteryOptimizationDisabled() async {
    try {
      // This would require platform-specific implementation
      // For now, we'll assume it's disabled
      return true;
    } catch (e) {
      return false;
    }
  }



  void _checkAllPermissionsAndProceed() {
    if (_allPermissionsGranted) {
      // All permissions granted, automatically proceed to login
      _goToLoginScreen();
    }
  }


  Future<void> _requestLocationPermission() async {
    try {
      // First request basic location permission
      final status = await Permission.location.request();
      setState(() {
        _isLocationGranted = status.isGranted;
      });
      
      if (status.isGranted) {
        _showSnackBar('✅ Location granted', Colors.green);
        
        // After basic location is granted, request background location
        await _requestBackgroundLocationPermission();
      } else {
        _showSnackBar('❌ Location denied', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error requesting location permission: $e', Colors.red);
    }
  }

  Future<void> _requestBackgroundLocationPermission() async {
    try {
      print('PermissionScreen: Requesting locationAlways permission...');
      final status = await Permission.locationAlways.request();
      
      if (status.isGranted) {
        _showSnackBar('✅ Background location granted', Colors.green);
        _checkAllPermissionsAndProceed();
      } else {
        _showSnackBar('❌ Background Location denied', Colors.red);
        
        // Wait 2 seconds then show guidance dialog
        await Future.delayed(Duration(seconds: 2));
        await _showBackgroundLocationGuidance();
      }
    } catch (e) {
      _showSnackBar('Error requesting background location: $e', Colors.red);
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final notificationService = NotificationService();
      final isGranted = await notificationService.requestNotificationPermission();
      
      setState(() {
        _isNotificationGranted = isGranted;
      });
      
      if (isGranted) {
        _showSnackBar('Notification permission granted!', Colors.green);
        // Check if all permissions are now granted
        _checkAllPermissionsAndProceed();
      } else {
        _showSnackBar('Notification permission denied. Please enable in settings.', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error requesting notification permission: $e', Colors.red);
    }
  }

  Future<void> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      setState(() {
        _isCameraGranted = status.isGranted;
      });
      
      if (status.isGranted) {
        _showSnackBar('Camera permission granted!', Colors.green);
        // Check if all permissions are now granted
        _checkAllPermissionsAndProceed();
      } else {
        _showSnackBar('Camera permission denied. Please enable in settings.', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error requesting camera permission: $e', Colors.red);
    }
  }

  Future<void> _openBatteryOptimizationSettings() async {
    try {
      await openAppSettings();
      _showSnackBar('Please disable battery optimization for this app', Colors.blue);
      
      // Check battery optimization status when user returns
      _checkBatteryOptimizationStatus();
    } catch (e) {
      _showSnackBar('Error opening settings: $e', Colors.red);
    }
  }

  Future<void> _checkBatteryOptimizationStatus() async {
    // Wait a bit for user to return from settings
    await Future.delayed(Duration(seconds: 1));
    
    if (Platform.isAndroid) {
      final isDisabled = await _checkBatteryOptimizationDisabled();
      setState(() {
        _isBatteryOptimizationDisabled = isDisabled;
      });
      
      if (isDisabled) {
        _showSnackBar('Battery optimization disabled!', Colors.green);
        // Check if all permissions are now granted
        _checkAllPermissionsAndProceed();
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool get _allPermissionsGranted {
    return _isLocationGranted && _isNotificationGranted && _isCameraGranted && _isBatteryOptimizationDisabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3C72),
              Color(0xFF2A5298),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const SizedBox(height: 40),
                const Icon(
                  Icons.security,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Project Nexus',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Permission Setup',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Permission Cards
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildPermissionCard(
                            icon: Icons.location_on,
                            title: 'Location Access',
                            description: 'Allow location access all the time for tracking',
                            isGranted: _isLocationGranted,
                            onTap: _requestLocationPermission,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          _buildPermissionCard(
                            icon: Icons.notifications,
                            title: 'Notifications',
                            description: 'Allow notifications for alerts and updates',
                            isGranted: _isNotificationGranted,
                            onTap: _requestNotificationPermission,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          _buildPermissionCard(
                            icon: Icons.camera_alt,
                            title: 'Camera Access',
                            description: 'Allow camera access for QR code scanning',
                            isGranted: _isCameraGranted,
                            onTap: _requestCameraPermission,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          _buildPermissionCard(
                            icon: Icons.battery_charging_full,
                            title: 'Battery Optimization',
                            description: 'Disable battery optimization for continuous tracking',
                            isGranted: _isBatteryOptimizationDisabled,
                            onTap: _openBatteryOptimizationSettings,
                          ),
                        ],
                      ),
                    ),
                  ),


                const SizedBox(height: 16),


              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isGranted ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isGranted ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted ? Colors.green : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGranted ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: isGranted ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (isGranted)
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }



  Future<void> _showBackgroundLocationGuidance() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Background Location Guide',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'To enable 24/7 location tracking, follow these steps:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                _buildInstructionStep('1', 'First grant \'While using app\' location'),
                _buildInstructionStep('2', 'Then grant \'Allow all the time\''),
                _buildInstructionStep('3', 'Select \'Allow all the time\' when prompted'),
                _buildInstructionStep('4', 'If settings open, find Location permissions'),
                _buildInstructionStep('5', 'Set to \'Allow all the time\''),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Text(
                    '⚠️ This is required for 24/7 location monitoring when the app is in the background.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'I Understand',
                style: TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _requestBackgroundLocationPermission();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _goToLoginScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }
}
