import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import 'otp_screen.dart';
import 'result_screen.dart';

enum ScanMode { passport, document, idCard }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  CameraController? _camCtrl;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;
  bool _cameraError = false;
  bool _isCapturing = false;
  bool _torchOn = false;

  ScanMode _mode = ScanMode.document;

  // Scan line animation
  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;
  bool _scanLineVisible = false;

  // Flash overlay
  double _flashOpacity = 0;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _scanLineAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut));
    _initCamera();
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _camCtrl?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _cameraError = true);
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('No cameras found');

      final backCam = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _camCtrl = CameraController(
        backCam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camCtrl!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  Future<void> _toggleTorch() async {
    if (_camCtrl == null || !_cameraReady) return;
    try {
      _torchOn = !_torchOn;
      await _camCtrl!.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _capture() async {
    if (_isCapturing || _camCtrl == null || !_cameraReady) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isCapturing = true;
      _scanLineVisible = true;
      _flashOpacity = 0.85;
    });

    _scanLineCtrl.repeat(reverse: true);

    // Flash effect
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _flashOpacity = 0);
    });

    try {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      final XFile img = await _camCtrl!.takePicture();
      _scanLineCtrl.stop();
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _scanLineVisible = false;
        });
        _goToResult(img.path);
      }
    } catch (e) {
      _scanLineCtrl.stop();
      if (mounted)
        setState(() {
          _isCapturing = false;
          _scanLineVisible = false;
        });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (img != null && mounted) _goToResult(img.path);
  }

  void _goToResult(String path) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, b) => ResultScreen(imagePath: path),
        transitionsBuilder: (_, a, b, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // ✅ NEW: Navigate to OTP screen with smooth transition
  void _goToOtp() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, b) => const OtpScreen(),
        transitionsBuilder: (_, a, b, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeInOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  double get _frameAspect => switch (_mode) {
    ScanMode.passport => 0.71,
    ScanMode.document => 1.4,
    ScanMode.idCard => 1.58,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──
          if (_cameraReady)
            CameraPreview(_camCtrl!)
          else if (_cameraError)
            _NoCameraView(onRetry: _initCamera)
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),

          // ── Scan frame overlay ──
          _buildScanOverlay(),

          // ── Flash overlay ──
          AnimatedOpacity(
            opacity: _flashOpacity,
            duration: const Duration(milliseconds: 250),
            child: Container(color: Colors.white),
          ),

          // ── Top bar ──
          _buildTopBar(),

          // ── Status badge ──
          _buildStatusBadge(),

          // ── Camera stats ──
          if (_cameraReady) _buildCamStats(),

          // ── Bottom controls ──
          _buildBottomControls(),

          // ── Bottom nav ──
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth * 0.78;
        final h = w / _frameAspect;
        final top =
            (constraints.maxHeight - h) / 2 - constraints.maxHeight * 0.04;

        return Stack(
          children: [
            // Dimmed areas
            Positioned.fill(
              child: CustomPaint(
                painter: _OverlayPainter(
                  frameRect: Rect.fromLTWH(
                    (constraints.maxWidth - w) / 2,
                    top,
                    w,
                    h,
                  ),
                ),
              ),
            ),
            // Corner brackets
            Positioned(
              left: (constraints.maxWidth - w) / 2,
              top: top,
              width: w,
              height: h,
              child: const _FrameCorners(),
            ),
            // Scan line
            if (_scanLineVisible)
              AnimatedBuilder(
                animation: _scanLineAnim,
                builder: (_, __) {
                  final lineY = top + _scanLineAnim.value * h;
                  return Positioned(
                    top: lineY,
                    left: (constraints.maxWidth - w) / 2 + w * 0.05,
                    width: w * 0.9,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.bluePri,
                            AppColors.accent,
                            AppColors.bluePri,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.bluePri.withOpacity(.8),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xD9000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 14,
          20,
          14,
        ),
        child: Row(
          children: [
            // Torch
            GestureDetector(
              onTap: _toggleTorch,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _torchOn
                      ? Colors.amber.withOpacity(.25)
                      : Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _torchOn
                        ? Colors.amber.withOpacity(.5)
                        : Colors.white.withOpacity(.15),
                  ),
                ),
                child: Icon(
                  _torchOn
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  color: _torchOn ? Colors.amber : Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'SCANNER',
              style: GoogleFonts.syne(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(.15)),
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final label = _isCapturing
        ? 'SCANNING…'
        : (_cameraReady ? 'READY TO SCAN' : 'CAMERA OFFLINE');
    final dotColor = _isCapturing
        ? AppColors.orange
        : (_cameraReady ? AppColors.green : AppColors.textMid);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 72,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.55),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDot(
                color: dotColor,
                animate: _cameraReady && !_isCapturing,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCamStats() {
    return Positioned(
      bottom: 280,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('ISO', '100'),
          _statItem('Shutter', '1/250s'),
          _statItem('Res', '300DPI'),
        ],
      ),
    );
  }

  Widget _statItem(String label, String val) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 82,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xF2000000), Color(0xB3000000), Colors.transparent],
            stops: [0, .6, 1],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
        child: Column(
          children: [
            // Mode selector
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.07),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withOpacity(.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: ScanMode.values.map((m) {
                  final label = switch (m) {
                    ScanMode.passport => 'PASSPORT',
                    ScanMode.document => 'DOCUMENT',
                    ScanMode.idCard => 'ID CARD',
                  };
                  final active = m == _mode;
                  return GestureDetector(
                    onTap: () => setState(() => _mode = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active ? AppColors.bluePri : Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: AppColors.bluePri.withOpacity(.45),
                                  blurRadius: 16,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .8,
                          color: active ? Colors.white : Colors.white54,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            // Capture row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gallery
                GestureDetector(
                  onTap: _pickFromGallery,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(.15)),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                // Capture btn
                GestureDetector(
                  onTap: _capture,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.bluePri, AppColors.blueLight],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withOpacity(.2),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bluePri.withOpacity(.5),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isCapturing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(.9),
                                  width: 2.5,
                                ),
                                color: Colors.white.withOpacity(.15),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.circle,
                                  color: Colors.white70,
                                  size: 10,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                // AI enhance
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(.15)),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white60,
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ UPDATED: Added OTP tab to bottom nav
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.9),
        border: const Border(top: BorderSide(color: Color(0x0FFFFFFF))),
      ),
      padding: EdgeInsets.fromLTRB(
        0,
        12,
        0,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(
            Icons.home_outlined,
            'Home',
            onTap: () => Navigator.pop(context),
          ),
          GestureDetector(
            onTap: _capture,
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.bluePri, AppColors.blueLight],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bluePri.withOpacity(.45),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          _navItem(Icons.grid_view_rounded, 'Gallery', onTap: _pickFromGallery),
          // ✅ NEW: OTP tab
          _navItem(Icons.shield_outlined, 'OTP', onTap: _goToOtp),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white30, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: Colors.white30,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overlay painter (dims everything outside frame) ───
class _OverlayPainter extends CustomPainter {
  final Rect frameRect;
  _OverlayPainter({required this.frameRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(.55);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(full)
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(4)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.frameRect != frameRect;
}

// ─── Frame corner brackets ───
class _FrameCorners extends StatelessWidget {
  const _FrameCorners();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: 0, left: 0, child: _corner(top: true, left: true)),
        Positioned(top: 0, right: 0, child: _corner(top: true, left: false)),
        Positioned(bottom: 0, left: 0, child: _corner(top: false, left: true)),
        Positioned(
          bottom: 0,
          right: 0,
          child: _corner(top: false, left: false),
        ),
      ],
    );
  }

  Widget _corner({required bool top, required bool left}) {
    return CustomPaint(
      size: const Size(28, 28),
      painter: _CornerPainter(top: top, left: left),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top, left;
  _CornerPainter({required this.top, required this.left});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final dx = left ? size.width : -size.width;
    final dy = top ? size.height : -size.height;
    path.moveTo(x + dx * 0.8, y);
    path.lineTo(x, y);
    path.lineTo(x, y + dy * 0.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Pulsing dot ───
class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulsingDot({required this.color, required this.animate});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final opacity = widget.animate
            ? Tween<double>(begin: 1, end: .35).evaluate(_ctrl)
            : 1.0;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: widget.color.withOpacity(.6), blurRadius: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── No camera view ───
class _NoCameraView extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoCameraView({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: Colors.white.withOpacity(.3),
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera access needed for scanning documents',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bluePri,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Allow Camera Access',
                style: GoogleFonts.syne(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: openAppSettings,
              child: Text(
                'Open Settings',
                style: GoogleFonts.dmSans(
                  color: AppColors.accent,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
