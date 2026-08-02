import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _manualController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isFlashOn = false;
  bool _isBackCamera = true;
  bool _hasSignalled = false;

  Color get _primaryGreen => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);

  @override
  void dispose() {
    _manualController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  bool _isShowingError = false;

  void _handleParsedCode(String rawCode) {
    if (_hasSignalled) return;
    
    // Extract session ID from the payload (handles phr://session/sess_xxxx or raw sess_xxxx)
    String sessionId = rawCode.trim();
    if (sessionId.startsWith('phr://session/')) {
      sessionId = sessionId.replaceFirst('phr://session/', '');
    }

    if (sessionId.startsWith('sess_')) {
      _hasSignalled = true;
      Navigator.pop(context, sessionId);
    } else {
      if (!_isShowingError) {
        _isShowingError = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid session QR code. Please scan a valid clinician gateway QR.'),
            backgroundColor: Colors.amber[900],
            duration: const Duration(seconds: 2),
          ),
        ).closed.then((_) {
          if (mounted) {
            setState(() {
              _isShowingError = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Scan Session QR',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            tooltip: 'Toggle Flashlight',
            onPressed: () {
              _scannerController.toggleTorch();
              setState(() {
                _isFlashOn = !_isFlashOn;
              });
            },
          ),
          IconButton(
            icon: Icon(_isBackCamera ? Icons.camera_rear_rounded : Icons.camera_front_rounded),
            tooltip: 'Switch Camera',
            onPressed: () {
              _scannerController.switchCamera();
              setState(() {
                _isBackCamera = !_isBackCamera;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Mobile Scanner Viewport
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleParsedCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // 2. Translucent Scanning Overlay Cover
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.55),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 250,
                    width: 250,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Glowing Corner Borders
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: 250,
              width: 250,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _buildCorner(isTop: true, isLeft: true),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildCorner(isTop: true, isLeft: false),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: _buildCorner(isBottom: true, isLeft: true),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _buildCorner(isBottom: true, isLeft: false),
                  ),
                ],
              ),
            ),
          ),

          // 4. Instructions and Manual Text Input at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121212) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Point camera at the clinician\'s screen QR code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 18),
                  
                  // Divider representing option separation
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR ENTER MANUALLY',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Manual Text Entry Form for Web testing and backups
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualController,
                          textCapitalization: TextCapitalization.none,
                          style: const TextStyle(fontFamily: 'Courier', fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'e.g. sess_882910',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _primaryGreen, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          final text = _manualController.text.trim();
                          if (text.isNotEmpty) {
                            _handleParsedCode(text);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({
    bool isTop = false,
    bool isBottom = false,
    bool isLeft = false,
  }) {
    const double size = 32;
    const double thickness = 4;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: _primaryGreen, width: thickness) : BorderSide.none,
          bottom: isBottom ? BorderSide(color: _primaryGreen, width: thickness) : BorderSide.none,
          left: isLeft ? BorderSide(color: _primaryGreen, width: thickness) : BorderSide.none,
          right: !isLeft ? BorderSide(color: _primaryGreen, width: thickness) : BorderSide.none,
        ),
      ),
    );
  }
}
