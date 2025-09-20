import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'dart:io';

class QRScannerScreen extends StatefulWidget {
  final String scanType; // 'token' or 'deployment'
  final Function(String) onScanned;

  const QRScannerScreen({
    Key? key,
    required this.scanType,
    required this.onScanned,
  }) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (isScanning && capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      if (barcode.rawValue != null) {
        setState(() {
          isScanning = false;
        });
        
        // Stop scanning
        controller.stop();
        
        // Process the scanned data
        _processScannedData(barcode.rawValue!);
      }
    }
  }

  void _processScannedData(String scannedData) {
    print('=== QR SCAN RESULT ===');
    print('Scan Type: ${widget.scanType}');
    print('Scanned Data: $scannedData');
    
    // Validate the scanned data
    if (scannedData.trim().isEmpty) {
      _showErrorDialog('Invalid QR Code', 'The scanned QR code is empty.');
      return;
    }
    
    String cleanData = scannedData.trim();
    
    // Try to parse as JSON and extract the specific value
    try {
      // Check if it's a JSON string
      if (cleanData.startsWith('{') && cleanData.endsWith('}')) {
        // Parse JSON
        Map<String, dynamic> jsonData = json.decode(cleanData);
        
        if (widget.scanType == 'token') {
          // For API Token, look for common token fields
          cleanData = jsonData['apiToken'] ?? 
                     jsonData['token'] ?? 
                     jsonData['api_key'] ?? 
                     jsonData['key'] ?? 
                     cleanData; // fallback to original
        } else if (widget.scanType == 'deployment') {
          // For Deployment Code, look for deploymentCode field
          cleanData = jsonData['deploymentCode'] ?? 
                     jsonData['deployment_code'] ?? 
                     jsonData['code'] ?? 
                     cleanData; // fallback to original
        }
        
        print('Extracted Value: $cleanData');
      }
    } catch (e) {
      print('Not a valid JSON, using raw data: $cleanData');
      // If it's not JSON, use the raw data as is
    }
    
    // Show success dialog
    _showSuccessDialog(cleanData);
  }

  void _showSuccessDialog(String data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                'QR Code Scanned',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.scanType == 'token' ? 'API Token' : 'Deployment Code'}:',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  data,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resumeScanning();
              },
              child: Text(
                'Scan Again',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onScanned(data);
                Navigator.of(context).pop(); // Go back to login screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Use This Code'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resumeScanning();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  void _resumeScanning() {
    setState(() {
      isScanning = true;
    });
    controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Scan ${widget.scanType == 'token' ? 'API Token' : 'Deployment Code'} QR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: _onDetect,
                  ),
                  // Custom overlay
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.green,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Position the QR code within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Scanning ${widget.scanType == 'token' ? 'API Token' : 'Deployment Code'}...',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
