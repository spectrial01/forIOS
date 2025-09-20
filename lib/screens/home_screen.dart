import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/background_service.dart';
import '../services/connectivity_service.dart';
import '../services/device_service.dart';
import '../services/update_service.dart';
import 'update_dialog.dart';
import '../main.dart'; // To access navigatorKey

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize dashboard when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // If user is not logged in, redirect to login
        if (!authProvider.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/login');
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        return Scaffold(
        appBar: AppBar(
          title: const Text('Project Nexus Dashboard'),
          backgroundColor: const Color(0xFF1E3C72),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _checkForUpdates,
              icon: const Icon(Icons.system_update),
              tooltip: 'Check for Updates',
            ),
          ],
        ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E3C72),
                  Color(0xFF2A5298),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Consumer<DashboardProvider>(
                  builder: (context, dashboardProvider, child) {
                    if (!dashboardProvider.isInitialized) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Initializing Dashboard...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Provider.of<DashboardProvider>(context, listen: false).initialize();
                              },
                              child: const Text(
                                'Retry',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return RefreshIndicator(
                      onRefresh: () async {
                        // Refresh all data and send update to webapp server
                        await dashboardProvider.refresh();
                        
                        // Also request location permission if needed
                        await dashboardProvider.requestLocationPermission();
                      },
                      color: const Color(0xFF1E3C72),
                      backgroundColor: Colors.white,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Device Status Cards
                            _buildStatusCard(
                              'Signal Status',
                              dashboardProvider.signalStatusDisplay,
                              dashboardProvider.signalStrength,
                              '%',
                              Icons.signal_cellular_alt,
                              _getStatusColor(dashboardProvider.signalColor),
                            ),
                            
                            const SizedBox(height: 16),
                      
                            _buildStatusCard(
                              'Battery Percentage',
                              dashboardProvider.batteryStatus,
                              dashboardProvider.batteryLevel,
                              '%',
                              Icons.battery_std,
                              _getStatusColor(dashboardProvider.batteryColor),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Speed and Update Interval Card
                            _buildSpeedCard(
                              'Current Speed',
                              '${dashboardProvider.currentSpeed.toStringAsFixed(1)} km/h',
                              'Update: ${dashboardProvider.currentUpdateInterval}s',
                              Icons.speed,
                              Colors.blue,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            _buildStatusCard(
                              'Session Verification',
                              dashboardProvider.sessionStatus,
                              null,
                              '',
                              Icons.verified_user,
                              _getStatusColor(dashboardProvider.sessionColor),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            _buildBackgroundServiceCard(),
                            
                            const SizedBox(height: 32),
                            
                            // Logout Button
                            _buildLogoutButton(context),
                            
                            const SizedBox(height: 20),
                            
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(
    String title,
    String status,
    int? value,
    String unit,
    IconData icon,
    Color statusColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 32,
              color: statusColor,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (value != null) ...[
                      Text(
                        '$value$unit',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard(
    String title,
    String speed,
    String updateInfo,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 32,
              color: color,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  speed,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  updateInfo,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // Helper function to navigate to login using multiple fallback methods
  void _navigateToLogin() {
    try {
      // Method 1: Try with current context if mounted
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.pushReplacementNamed(context, '/login');
        print('Navigation successful using widget context');
        return;
      }
    } catch (e) {
      print('Widget context navigation failed: $e');
    }
    
    try {
      // Method 2: Use GlobalKey (works even when widget is unmounted)
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.popUntil((route) => route.isFirst); // Clear all dialogs
        navigator.pushReplacementNamed('/login');
        print('Navigation successful using GlobalKey');
        return;
      }
    } catch (e) {
      print('GlobalKey navigation failed: $e');
    }
    
    print('All navigation methods failed - user may need to restart app');
  }

  // Complete logout function that stops all services and clears all data
  Future<void> _performCompleteLogout(BuildContext context) async {
    print('=== COMPLETE LOGOUT STARTED ===');
    
    try {
      // Store context check
      if (!mounted) return;
      
      // 1. Stop all tracking services FIRST (before server logout)
      print('Stopping all tracking services...');
      try {
        final deviceService = DeviceService();
        deviceService.stopPersistentNotification(); // This stops all tracking
        print('Tracking services stopped');
      } catch (e) {
        print('Error stopping tracking services: $e');
      }
      
      // 2. Stop background service with shorter timeout
      print('Stopping background service...');
      try {
        final backgroundService = BackgroundService();
        await backgroundService.stopService().timeout(
          const Duration(seconds: 2), // Reduced timeout
          onTimeout: () {
            print('Background service stop timeout - continuing...');
          },
        );
        print('Background service stopped');
      } catch (e) {
        print('Error stopping background service: $e');
      }
      
      // 3. Stop connectivity monitoring
      print('Stopping connectivity service...');
      try {
        final connectivityService = ConnectivityService();
        connectivityService.dispose();
        print('Connectivity service stopped');
      } catch (e) {
        print('Error stopping connectivity service: $e');
      }
      
      // 4. Clear cached data BEFORE provider disposal
      print('Clearing cached data...');
      try {
        await _clearAllCachedData().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            print('Cache clear timeout - continuing...');
          },
        );
        print('Cached data cleared');
      } catch (e) {
        print('Error clearing cached data: $e');
      }
      
      // 5. Reset dashboard provider data
      print('Resetting dashboard provider...');
      try {
        if (mounted) {
          final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
          dashboardProvider.dispose();
          print('Dashboard provider reset');
        }
      } catch (e) {
        print('Error resetting dashboard provider: $e');
      }
      
      // 6. Perform auth logout LAST (with shorter timeout)
      print('Performing auth logout (server API call)...');
      try {
        if (mounted) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.logout().timeout(
            const Duration(seconds: 3), // Reduced timeout
            onTimeout: () {
              print('Auth logout timeout - continuing...');
            },
          );
          print('Auth logout completed');
        }
      } catch (e) {
        print('Error during auth logout: $e');
        // Continue even if server logout fails
      }
      
      print('=== COMPLETE LOGOUT FINISHED ===');
      
    } catch (e) {
      print('Error during complete logout: $e');
      // Continue with logout even if some services fail
    }
  }

  // Clear all cached data from SharedPreferences
  Future<void> _clearAllCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all stored data
      await prefs.remove('user_data');
      await prefs.remove('auth_token');
      await prefs.remove('deployment_code');
      await prefs.remove('device_id');
      await prefs.remove('last_location');
      await prefs.remove('last_update_time');
      await prefs.remove('battery_level');
      await prefs.remove('signal_strength');
      await prefs.remove('current_speed');
      await prefs.remove('session_status');
      
      // Clear all keys (nuclear option)
      await prefs.clear();
      
      print('All cached data cleared successfully');
    } catch (e) {
      print('Error clearing cached data: $e');
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53E3E), Color(0xFFC53030)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _showLogoutDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String colorString) {
    switch (colorString) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close confirmation dialog
                
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext loadingContext) {
                    return WillPopScope(
                      onWillPop: () async => false,
                      child: AlertDialog(
                        content: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Logging out and stopping services...',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
                
                try {
                  // Perform logout with timeout
                  await _performCompleteLogout(context).timeout(
                    const Duration(seconds: 8),
                    onTimeout: () {
                      print('Complete logout timeout - forcing completion');
                    },
                  );
                  
                  print('Logout completed, navigating...');
                  
                  // Always navigate using GlobalKey (works even if widget is unmounted)
                  _navigateToLogin();
                  
                } catch (e) {
                  print('Logout error: $e');
                  // Navigate even on error
                  _navigateToLogin();
                }
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackgroundServiceCard() {
    final backgroundService = BackgroundService();
    final connectivityService = ConnectivityService();
    
    return FutureBuilder<bool>(
      future: backgroundService.isServiceActive(),
      builder: (context, snapshot) {
        final isServiceRunning = snapshot.data ?? false;
        final isOnline = connectivityService.isOnline;
        final connectionType = connectivityService.connectionType;
        
        String status;
        Color statusColor;
        IconData icon;
        
        if (isServiceRunning && isOnline) {
          status = 'Active';
          statusColor = Colors.green;
          icon = Icons.sync;
        } else if (isServiceRunning && !isOnline) {
          status = 'Offline';
          statusColor = Colors.orange;
          icon = Icons.cloud_off;
        } else {
          status = 'Inactive';
          statusColor = Colors.red;
          icon = Icons.sync_disabled;
        }
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Background Service',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isOnline) ...[
                          Text(
                            '($connectionType)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isServiceRunning) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.timer,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Adaptive tracking active',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkForUpdates() async {
    try {
      print('HomeScreen: Checking for updates...');
      
      final updateService = UpdateService();
      final result = await updateService.checkForUpdates();
      
      if (result.hasUpdate && result.updateInfo != null) {
        print('HomeScreen: Update available: ${result.updateInfo!.latestVersion}');
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: !result.updateInfo!.isRequired,
            builder: (context) => UpdateDialog(
              updateInfo: result.updateInfo!,
              currentVersion: result.currentVersion,
            ),
          );
        }
      } else {
        print('HomeScreen: No updates available');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'No updates available'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('HomeScreen: Error checking for updates: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking for updates: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}