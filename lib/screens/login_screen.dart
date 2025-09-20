import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';
import 'qr_scanner_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiTokenController = TextEditingController();
  final _deploymentController = TextEditingController();
  bool _obscureApiToken = true;
  bool _obscureDeployment = true;
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void dispose() {
    _apiTokenController.dispose();
    _deploymentController.dispose();
    super.dispose();
  }

  // Load version from package info
  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _version = 'Version ${packageInfo.version}';
      });
    } catch (e) {
      setState(() {
        _version = 'Version 1.0.0';
      });
    }
  }

  // QR Scanner methods
  void _scanQRCode(String type) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(
          scanType: type,
          onScanned: (scannedData) {
            if (type == 'token') {
              _apiTokenController.text = scannedData;
            } else {
              _deploymentController.text = scannedData;
            }
          },
        ),
      ),
    );
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Police Shield Logo
                  Container(
                    width: 120,
                    height: 120,
                    child: Image.asset(
                      'assets/images/pnp_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image not found
                        print('Image load error: $error');
                        return Icon(
                          Icons.shield,
                          size: 60,
                          color: Colors.white,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // App Title
                  const Text(
                    'Project Nexus',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Mobile Tracking Device',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Login Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3C72),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          
                          // API Token Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'API Token',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CustomTextField(
                                controller: _apiTokenController,
                                labelText: 'API TOKEN',
                                hintText: '',
                                obscureText: _obscureApiToken,
                                prefixIcon: Icons.vpn_key,
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _scanQRCode('token'),
                                      icon: Icon(Icons.qr_code_scanner, size: 20),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.all(6),
                                        minimumSize: Size(32, 32),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _obscureApiToken ? Icons.visibility : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureApiToken = !_obscureApiToken;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your API token';
                                  }
                                  if (value.length < 10) {
                                    return 'API token must be at least 10 characters';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Deployment Code Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deployment Code',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CustomTextField(
                                controller: _deploymentController,
                                labelText: 'DEPLOYMENT CODE',
                                hintText: '',
                                obscureText: _obscureDeployment,
                                prefixIcon: Icons.settings,
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _scanQRCode('deployment'),
                                      icon: Icon(Icons.qr_code_scanner, size: 20),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.all(6),
                                        minimumSize: Size(32, 32),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _obscureDeployment ? Icons.visibility : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureDeployment = !_obscureDeployment;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your deployment code';
                                  }
                                  if (value.length < 6) {
                                    return 'Deployment code must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Login Button
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return CustomButton(
                                text: 'Sign In',
                                onPressed: authProvider.isLoading ? null : _handleLogin,
                                isLoading: authProvider.isLoading,
                              );
                            },
                          ),
                          
                          // Error Message
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              if (authProvider.errorMessage != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(
                                    authProvider.errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Version Text (Dynamic from pubspec.yaml)
                          Text(
                            _version,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Set API token first
      authProvider.setApiToken(_apiTokenController.text.trim());
      
      // Then login with deployment code
      final success = await authProvider.login(
        _deploymentController.text.trim(),
      );
      
      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    }
  }
}

