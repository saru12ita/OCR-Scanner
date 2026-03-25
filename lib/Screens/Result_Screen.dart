import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme/app_colors.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  const ResultScreen({super.key, required this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String? _ocrText;
  bool _isProcessing = true;
  double _progress = 0;
  String _statusMsg = 'Initializing ML Kit…';
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _runOcr();
  }

  Future<void> _runOcr() async {
    try {
      setState(() {
        _statusMsg = 'Loading image…';
        _progress = 0.1;
      });
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _statusMsg = 'Detecting text regions…';
        _progress = 0.35;
      });
      await Future.delayed(const Duration(milliseconds: 300));

      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final inputImage = InputImage.fromFilePath(widget.imagePath);

      setState(() {
        _statusMsg = 'Recognizing text…';
        _progress = 0.6;
      });

      final RecognizedText result = await textRecognizer.processImage(
        inputImage,
      );

      setState(() {
        _statusMsg = 'Finalizing…';
        _progress = 0.9;
      });
      await Future.delayed(const Duration(milliseconds: 200));

      await textRecognizer.close();

      final text = result.text.trim().isEmpty
          ? '(No text detected in this image)'
          : result.text.trim();

      if (mounted) {
        setState(() {
          _ocrText = text;
          _isProcessing = false;
          _progress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ocrText = 'OCR failed: ${e.toString()}';
          _isProcessing = false;
          _progress = 1.0;
        });
      }
    }
  }

  Future<void> _copyText() async {
    if (_ocrText == null) return;
    await Clipboard.setData(ClipboardData(text: _ocrText!));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // Mesh
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.8),
                  radius: 1.0,
                  colors: [Color(0x1A22D48B), Color(0x00080E1F)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImageCard(),
                        const SizedBox(height: 16),
                        _buildOcrCard(),
                        const SizedBox(height: 16),
                        _buildActionRow(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(.15)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textHi,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Scan Result',
            style: GoogleFonts.syne(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textHi,
            ),
          ),
          const Spacer(),
          if (!_isProcessing && _ocrText != null && !_ocrText!.startsWith('('))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.green.withOpacity(.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.green,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Detected',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(.15)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.4), blurRadius: 40),
          ],
        ),
        child: Stack(
          children: [
            Image.file(
              File(widget.imagePath),
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            // Processing overlay
            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(.4),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2.5,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _statusMsg,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent.withOpacity(.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Icon(
                Icons.subject_rounded,
                color: AppColors.textLo,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                'EXTRACTED TEXT (OCR)',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLo,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.accent.withOpacity(.1),
                ),
              ),
              if (!_isProcessing && _ocrText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    '${_ocrText!.split(' ').length} words',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppColors.textLo,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (_isProcessing) ...[
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2,
                    value: _progress < 1 ? null : 1,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _statusMsg,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.textMid,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _progress),
                duration: const Duration(milliseconds: 400),
                builder: (_, val, __) => LinearProgressIndicator(
                  value: val,
                  backgroundColor: AppColors.bgSurface,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  minHeight: 3,
                ),
              ),
            ),
          ] else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: SelectableText(
                  _ocrText ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    height: 1.7,
                    color: AppColors.textMid,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _copyText,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                color: _copied
                    ? AppColors.green.withOpacity(.12)
                    : AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _copied
                      ? AppColors.green.withOpacity(.4)
                      : AppColors.accent.withOpacity(.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    color: _copied ? AppColors.green : AppColors.textHi,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _copied ? 'Copied!' : 'Copy Text',
                    style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _copied ? AppColors.green : AppColors.textHi,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.bluePri, AppColors.blueLight],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bluePri.withOpacity(.35),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rescan',
                    style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
