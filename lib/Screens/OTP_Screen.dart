import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import 'scanner_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  static const int otpLength = 6;
  static const String demoOtp = '529174';

  final List<String> _digits = List.filled(otpLength, '');
  int _activeIndex = 0;
  bool _isLoading = false;
  bool _hasError = false;

  // Timer
  int _timerSec = 59;
  Timer? _timer;
  bool _canResend = false;

  // Animations
  late AnimationController _shieldController;
  late AnimationController _pulseController;
  late AnimationController _errorController;

  // Toast
  OverlayEntry? _toastEntry;

  @override
  void initState() {
    super.initState();
    _shieldController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _startTimer();
  }

  @override
  void dispose() {
    _shieldController.dispose();
    _pulseController.dispose();
    _errorController.dispose();
    _timer?.cancel();
    _toastEntry?.remove();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timerSec = 59;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_timerSec > 0) {
          _timerSec--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  String get _timerLabel {
    final m = (_timerSec ~/ 60).toString().padLeft(2, '0');
    final s = (_timerSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _kbInput(String d) {
    if (_activeIndex >= otpLength) return;
    setState(() {
      _digits[_activeIndex] = d;
      _hasError = false;
      if (_activeIndex < otpLength - 1) _activeIndex++;
    });
    HapticFeedback.lightImpact();
  }

  void _kbDelete() {
    setState(() {
      _hasError = false;
      if (_digits[_activeIndex].isNotEmpty) {
        _digits[_activeIndex] = '';
      } else if (_activeIndex > 0) {
        _activeIndex--;
        _digits[_activeIndex] = '';
      }
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _verify() async {
    final code = _digits.join();
    if (code.length < otpLength) {
      _showToast('Please enter all 6 digits', ToastType.error);
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    if (code == demoOtp) {
      _showToast('✓ Verified! Opening scanner…', ToastType.success);
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, a, b) => const ScannerScreen(),
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
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      _showToast('Invalid code. Try again.', ToastType.error);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < otpLength; i++) _digits[i] = '';
        _activeIndex = 0;
        _hasError = false;
      });
    }
  }

  void _resend() {
    _showToast('Code resent to ••••• 8821', ToastType.info);
    _startTimer();
    setState(() {
      for (int i = 0; i < otpLength; i++) _digits[i] = '';
      _activeIndex = 0;
    });
  }

  void _showToast(String msg, ToastType type) {
    _toastEntry?.remove();
    final overlay = Overlay.of(context);
    _toastEntry = OverlayEntry(
      builder: (_) => _ToastWidget(message: msg, type: type),
    );
    overlay.insert(_toastEntry!);
    Future.delayed(const Duration(milliseconds: 3000), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // Mesh background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.6),
                radius: 1.0,
                colors: [Color(0x2E3355FF), Color(0x00080E1F)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        _buildShield(),
                        const SizedBox(height: 32),
                        _buildTitle(),
                        const SizedBox(height: 14),
                        _buildSubtitle(),
                        const SizedBox(height: 32),
                        _buildOtpCells(),
                        const SizedBox(height: 32),
                        _buildVerifyButton(),
                        const SizedBox(height: 24),
                        _buildResendRow(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                _buildSecurityFooter(),
                const SizedBox(height: 16),
                _buildNumpad(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShield() {
    return AnimatedBuilder(
      animation: _shieldController,
      builder: (_, __) {
        final offset = Tween<double>(begin: 0, end: -6).evaluate(
          CurvedAnimation(parent: _shieldController, curve: Curves.easeInOut),
        );
        return Transform.translate(
          offset: Offset(0, offset),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) {
                  final scale = Tween<double>(begin: 1.0, end: 1.6).evaluate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeOut,
                    ),
                  );
                  final opacity = Tween<double>(begin: 0.5, end: 0).evaluate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeOut,
                    ),
                  );
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.bluePri,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Shield box
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A2A55), Color(0xFF0F1A3A)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(.22),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.bluePri.withOpacity(.25),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.accent,
                  size: 34,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.syne(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -.5,
          color: AppColors.textHi,
        ),
        children: const [
          TextSpan(text: 'Verification\n'),
          TextSpan(
            text: 'Required',
            style: TextStyle(color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return Column(
      children: [
        Text(
          "We've sent a 6-digit code to your\nregistered mobile number ending in",
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColors.textMid,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withOpacity(.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.phone_android_rounded,
                color: AppColors.accent,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                '••••• 8821',
                style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ FIXED: Uses LayoutBuilder to calculate responsive cell width
  Widget _buildOtpCells() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double horizontalMarginPerCell = 10.0; // 5px each side
        final double totalMargin = horizontalMarginPerCell * otpLength;
        final double cellWidth =
            ((constraints.maxWidth - totalMargin) / otpLength).clamp(
              36.0,
              56.0,
            );
        final double cellHeight = cellWidth * 1.2;
        final double fontSize = cellWidth * 0.46;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(otpLength, (i) {
            final isActive = i == _activeIndex;
            final isFilled = _digits[i].isNotEmpty;
            return GestureDetector(
              onTap: () => setState(() => _activeIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: cellWidth,
                height: cellHeight,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: isFilled ? const Color(0xFF1C2D58) : AppColors.bgInput,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hasError
                        ? AppColors.red
                        : isActive
                        ? AppColors.bluePri
                        : isFilled
                        ? AppColors.accent.withOpacity(.4)
                        : AppColors.accent.withOpacity(.18),
                    width: isActive ? 2 : 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.blueGlow,
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : _hasError
                      ? [
                          BoxShadow(
                            color: AppColors.red.withOpacity(.2),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isFilled
                      ? Text(
                          _digits[i],
                          style: GoogleFonts.syne(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHi,
                          ),
                        )
                      : isActive
                      ? _BlinkingCursor()
                      : const SizedBox.shrink(),
                ),
              ).animate(target: _hasError ? 1 : 0).shake(duration: 300.ms),
            );
          }),
        );
      },
    );
  }

  Widget _buildVerifyButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _verify,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isLoading
                ? [
                    AppColors.bluePri.withOpacity(.6),
                    AppColors.blueLight.withOpacity(.6),
                  ]
                : [AppColors.bluePri, AppColors.blueLight],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.bluePri.withOpacity(.4),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Verify & Continue',
                      style: GoogleFonts.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: .4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildResendRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          "DIDN'T RECEIVE THE CODE?",
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textLo,
            letterSpacing: 1.2,
          ),
        ),
        GestureDetector(
          onTap: _canResend ? _resend : null,
          child: Text(
            'Resend Code',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _canResend ? AppColors.accent : AppColors.textLo,
            ),
          ),
        ),
        Text('|', style: TextStyle(color: AppColors.textLo)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.orange, size: 14),
            const SizedBox(width: 4),
            Text(
              _timerLabel,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.orange,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _secItem(Icons.lock_outline_rounded, 'END-TO-END ENCRYPTED'),
        const SizedBox(width: 28),
        _secItem(Icons.verified_user_outlined, 'SECURE GATEWAY'),
      ],
    );
  }

  Widget _secItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textLo, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textLo,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ✅ FIXED: All keys use Expanded — no fixed widths
  Widget _buildNumpad() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2340),
        border: Border(top: BorderSide(color: Color(0x267C9DFF), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: ['1', '2', '3', '4', '5'].map((d) => _numKey(d)).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ...['6', '7', '8', '9'].map((d) => _numKey(d)),
              _delKey(),
            ],
          ),
          const SizedBox(height: 6),
          Row(children: [_numKey('0', flex: 3), _doneKey(flex: 2)]),
        ],
      ),
    );
  }

  // ✅ FIXED: Uses Expanded with flex instead of fixed width
  Widget _numKey(String d, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _kbInput(d),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF253058),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.accent.withOpacity(.12)),
          ),
          child: Center(
            child: Text(
              d,
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textHi,
              ),
            ),
          ),
        ),
      ),
    );
  }

  //  FIXED: Uses Expanded instead of fixed width
  Widget _delKey() {
    return Expanded(
      child: GestureDetector(
        onTap: _kbDelete,
        child: Container(
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2B4A),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.accent.withOpacity(.12)),
          ),
          child: const Center(
            child: Icon(
              Icons.backspace_outlined,
              color: AppColors.textHi,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  //  FIXED: Uses Expanded with flex instead of fixed width
  Widget _doneKey({int flex = 1}) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: _verify,
        child: Container(
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: AppColors.bluePri.withOpacity(.25),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.bluePri.withOpacity(.3)),
          ),
          child: Center(
            child: Text(
              'Done',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Blinking cursor widget ───
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.blueLight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─── Toast widget ───
enum ToastType { success, error, info }

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  const _ToastWidget({required this.message, required this.type});
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _dotColor => switch (widget.type) {
    ToastType.success => AppColors.green,
    ToastType.error => AppColors.red,
    ToastType.info => AppColors.blueLight,
  };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -.3),
            end: Offset.zero,
          ).animate(_anim),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: AppColors.accent.withOpacity(.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.4),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.message,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textHi,
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
}
