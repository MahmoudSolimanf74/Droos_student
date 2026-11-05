import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/join_code_helper.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  /// Static helper to open the QR Scanner and return the scanned code.
  static Future<String?> open(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const QrScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  late final Animation<double> _scanAnimation;

  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue ?? barcode.displayValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        final code = JoinCodeHelper.extractCode(rawValue);
        if (code.isNotEmpty) {
          _hasScanned = true;
          HapticFeedback.mediumImpact();
          if (mounted) {
            Navigator.of(context).pop(code);
          }
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double scanBoxSize = 270.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.no_photography_rounded,
                            color: AppColors.red,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'تعذر فتح الكاميرا',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'يرجى منح إذن استخدام الكاميرا من إعدادات الهاتف لمسح رمز الـ QR، أو إدخال الكود يدوياً.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                          label: const Text(
                            'إدخال الكود يدوياً',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Custom Dark Mask & Corner Frame
          CustomPaint(
            painter: _ScannerOverlayPainter(
              scanBoxSize: scanBoxSize,
              borderColor: AppColors.primary,
            ),
          ),

          // Animated Laser Line inside Scanner Box
          Center(
            child: SizedBox(
              width: scanBoxSize - 20,
              height: scanBoxSize,
              child: AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment(0, (_scanAnimation.value * 2) - 1),
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Top App Bar Controls
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back / Close Button
                    _CircularActionButton(
                      icon: Icons.close_rounded,
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(context).pop(),
                    ),

                    // Title
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'مسح رمز المجموعة',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Controls: Torch & Camera Switch
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            final isTorchOn = state.torchState == TorchState.on;
                            return _CircularActionButton(
                              icon: isTorchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              iconColor: isTorchOn
                                  ? AppColors.yellow
                                  : Colors.white,
                              tooltip: 'الفلاش',
                              onPressed: () => _controller.toggleTorch(),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _CircularActionButton(
                          icon: Icons.flip_camera_ios_rounded,
                          tooltip: 'تبديل الكاميرا',
                          onPressed: () => _controller.switchCamera(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Hint & Manual Input Button
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.center_focus_strong_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'وجّه الكاميرا نحو رمز QR المعروض لدى المعلم',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor: AppColors.surface.withValues(alpha: 0.85),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: const Text(
                        'أو إدخال الكود يدويًا',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color iconColor;

  const _CircularActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanBoxSize;
  final Color borderColor;

  _ScannerOverlayPainter({
    required this.scanBoxSize,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double left = (size.width - scanBoxSize) / 2;
    final double top = (size.height - scanBoxSize) / 2;
    final double right = left + scanBoxSize;
    final double bottom = top + scanBoxSize;

    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    // Cutout target area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          const Radius.circular(20),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // Draw 4 corner brackets
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;
    const radius = 18.0;

    // Top-Left Corner
    final topLeft = Path()
      ..moveTo(left, top + cornerLength)
      ..lineTo(left, top + radius)
      ..arcToPoint(Offset(left + radius, top), radius: const Radius.circular(radius))
      ..lineTo(left + cornerLength, top);
    canvas.drawPath(topLeft, cornerPaint);

    // Top-Right Corner
    final topRight = Path()
      ..moveTo(right - cornerLength, top)
      ..lineTo(right - radius, top)
      ..arcToPoint(Offset(right, top + radius), radius: const Radius.circular(radius))
      ..lineTo(right, top + cornerLength);
    canvas.drawPath(topRight, cornerPaint);

    // Bottom-Left Corner
    final bottomLeft = Path()
      ..moveTo(left, bottom - cornerLength)
      ..lineTo(left, bottom - radius)
      ..arcToPoint(Offset(left + radius, bottom), radius: const Radius.circular(radius), clockwise: false)
      ..lineTo(left + cornerLength, bottom);
    canvas.drawPath(bottomLeft, cornerPaint);

    // Bottom-Right Corner
    final bottomRight = Path()
      ..moveTo(right - cornerLength, bottom)
      ..lineTo(right - radius, bottom)
      ..arcToPoint(Offset(right, bottom - radius), radius: const Radius.circular(radius))
      ..lineTo(right, bottom - cornerLength);
    canvas.drawPath(bottomRight, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
