import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/scan_provider.dart';
import 'product_detail_screen.dart';
import 'not_found_screen.dart';
import 'ocr_camera_screen.dart';

/// Live camera barcode scanner PLUS a manual barcode entry field.
/// Both paths funnel through the same ScanProvider.lookupBarcode call,
/// so the backend/API logic is fully reused.
class ScanScreen extends StatefulWidget {
  final String initialCategory;
  const ScanScreen({super.key, this.initialCategory = 'food'});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
  );
  final TextEditingController _manualBarcodeController = TextEditingController();
  final FocusNode _manualBarcodeFocus = FocusNode();

  bool _handling = false;
  bool _torchOn = false;
  String? _manualError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScanProvider>().setCategory(widget.initialCategory);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualBarcodeController.dispose();
    _manualBarcodeFocus.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;
    await _controller.stop();
    await _handleBarcode(barcode);
    if (!mounted) return;
    await _controller.start();
  }

  Future<void> _handleManualSubmit() async {
    final value = _manualBarcodeController.text.trim();
    if (value.isEmpty) {
      setState(() => _manualError = 'Enter a barcode number');
      return;
    }
    if (!RegExp(r'^\d{6,14}$').hasMatch(value)) {
      setState(() => _manualError = 'Enter a valid numeric barcode');
      return;
    }
    setState(() => _manualError = null);
    _manualBarcodeFocus.unfocus();
    await _controller.stop();
    await _handleBarcode(value);
    if (!mounted) return;
    await _controller.start();
  }

  /// Shared resolution path for both camera-detected and manually-entered
  /// barcodes. Uses the existing ScanProvider -> ProductService -> backend
  /// barcode-analysis API - nothing about that flow changes.
  Future<void> _handleBarcode(String barcode) async {
    if (_handling) return;
    setState(() => _handling = true);

    final scan = context.read<ScanProvider>();
    await scan.lookupBarcode(barcode);

    if (!mounted) {
      setState(() => _handling = false);
      return;
    }

    if (scan.stage == ScanStage.notFound) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NotFoundScreen(barcode: barcode)),
      );
    } else if (scan.product != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProductDetailScreen()),
      );
    } else if (scan.stage == ScanStage.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(scan.errorMessage ?? 'Something went wrong')),
      );
    }

    if (!mounted) return;
    setState(() => _handling = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Camera preview section
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(controller: _controller, onDetect: _onDetect),
                  Container(color: Colors.black.withValues(alpha: 0.30)),
                  _buildScanFrame(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _circleButton(Icons.close_rounded, () => Navigator.of(context).pop()),
                        const Text(
                          'Scan Barcode',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        _circleButton(
                          _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          () {
                            _controller.toggleTorch();
                            setState(() => _torchOn = !_torchOn);
                          },
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Column(
                      children: [
                        const Text(
                          'Align the barcode within the frame',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const OcrCameraScreen()),
                          ),
                          icon: const Icon(Icons.document_scanner_outlined, color: Colors.white),
                          label: const Text('No barcode? Scan ingredients label',
                              style: TextStyle(color: Colors.white)),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white24,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_handling)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),

            // Manual barcode entry section (always visible below the camera)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Or enter barcode manually',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualBarcodeController,
                          focusNode: _manualBarcodeFocus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.search,
                          enabled: !_handling,
                          onSubmitted: (_) => _handleManualSubmit(),
                          decoration: InputDecoration(
                            hintText: 'e.g. 8901030895555',
                            errorText: _manualError,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _handling ? null : _handleManualSubmit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: _handling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Search'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanFrame() {
    return Center(
      child: Container(
        width: 260,
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.greenMid, width: 2.5),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}