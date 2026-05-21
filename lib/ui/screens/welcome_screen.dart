import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../agent/agent_coordinator.dart';
import '../painters/tactical_grid_painter.dart';
import 'aegis_shell.dart';

class AegisWelcomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const AegisWelcomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<AegisWelcomeScreen> createState() => _AegisWelcomeScreenState();
}

class _AegisWelcomeScreenState extends State<AegisWelcomeScreen>
    with TickerProviderStateMixin {
  final AgentCoordinator _agent = AgentCoordinator();

  bool _isEngineReady = false;
  String? _initError;
  String _statusMessage = 'Mounting offline database & collections...';
  int _downloadProgress = -1;

  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _runInitialization();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _runInitialization() async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      setState(() {
        _statusMessage = 'Verifying Gemma AI weights...';
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      await _agent.initialize(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _statusMessage = 'Downloading Gemma AI weights...';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _downloadProgress = -1;
          _statusMessage =
              'Verifying tactical co-processor & hardware acceleration...';
        });
      }

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      setState(() {
        _statusMessage = 'Aegis fully calibrated and ready.';
        _isEngineReady = true;
      });
      _fadeController.forward();
    } catch (error) {
      if (mounted) {
        setState(() {
          _initError = error.toString();
          _statusMessage = 'Initialization failed.';
        });
      }
    }
  }

  void _enterAegis() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AegisShell(
          isDarkMode: isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          agent: _agent,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.15),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isDarkMode) {
    if (_isEngineReady) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (isDarkMode
                  ? const Color(0xFF00E5FF)
                  : const Color(0xFF007A8C))
              .withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_circle_rounded,
          color:
              isDarkMode ? const Color(0xFF00E5FF) : const Color(0xFF007A8C),
          size: 20,
        ),
      );
    }

    if (_initError != null) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error_rounded,
          color: Colors.redAccent,
          size: 20,
        ),
      );
    }

    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(
          isDarkMode ? const Color(0xFF00E5FF) : const Color(0xFF007A8C),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeCyan = const Color(0xFF00E5FF);
    final softCyan = const Color(0xFF00B4D8);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFF070B14),
                    const Color(0xFF0F1524),
                    const Color(0xFF070B14),
                  ]
                : [
                    const Color(0xFFFAFAFC),
                    const Color(0xFFECEFF1),
                    const Color(0xFFFAFAFC),
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      activeCyan.withOpacity(isDarkMode ? 0.08 : 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              right: -150,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      softCyan.withOpacity(isDarkMode ? 0.08 : 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: TacticalGridPainter(isDarkMode: isDarkMode),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulseController.value * 0.08);
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 88 * scale,
                                height: 88 * scale,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: activeCyan.withOpacity(
                                        0.2 - (_pulseController.value * 0.1)),
                                    width: 2,
                                  ),
                                ),
                              ),
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF161B22)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeCyan.withOpacity(0.15),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isDarkMode
                                        ? const Color(0xFF30363D)
                                        : const Color(0xFFE2DED8),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.shield_outlined,
                                  size: 38,
                                  color: isDarkMode
                                      ? activeCyan
                                      : const Color(0xFF007A8C),
                                ),
                              ),
                              Positioned(
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: isDarkMode
                                      ? activeCyan
                                      : const Color(0xFF007A8C),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'A E G I S',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color:
                              isDarkMode ? Colors.white : const Color(0xFF1F1F1F),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'OFFLINE TACTICAL CLINICAL COPILOT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: isDarkMode ? Colors.white60 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 36),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 24),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.black.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDarkMode
                                    ? const Color(0xFF30363D).withOpacity(0.5)
                                    : const Color(0xFFE2DED8).withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildStatusIndicator(isDarkMode),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'AEGIS SECURE ENGINE INITIALIZATION',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                              color: isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _statusMessage,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode
                                                  ? Colors.white.withOpacity(0.9)
                                                  : const Color(0xFF1F1F1F),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_downloadProgress >= 0) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: _downloadProgress / 100.0,
                                            backgroundColor: isDarkMode
                                                ? const Color(0xFF21262D)
                                                : const Color(0xFFE5E5E5),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              isDarkMode
                                                  ? const Color(0xFF00E5FF)
                                                  : const Color(0xFF007A8C),
                                            ),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '$_downloadProgress%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? const Color(0xFF00E5FF)
                                              : const Color(0xFF007A8C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_initError != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x22FF5252),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFFF5252), width: 1),
                          ),
                          child: Text(
                            'Engine Init Failed: $_initError',
                            style: const TextStyle(
                                color: Color(0xFFFF6B6B), fontSize: 13),
                          ),
                        )
                      else
                        FadeTransition(
                          opacity: _isEngineReady
                              ? _fadeController
                              : const AlwaysStoppedAnimation(0.4),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isEngineReady ? _enterAegis : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDarkMode
                                    ? activeCyan
                                    : const Color(0xFF007A8C),
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: isDarkMode
                                    ? const Color(0xFF161B22)
                                    : const Color(0xFFE5E5E5),
                                disabledForegroundColor: isDarkMode
                                    ? Colors.white24
                                    : Colors.black26,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: _isEngineReady
                                        ? Colors.transparent
                                        : (isDarkMode
                                            ? const Color(0xFF30363D)
                                            : const Color(0xFFE5E5E5)),
                                  ),
                                ),
                              ),
                              child: Text(
                                _isEngineReady
                                    ? 'START'
                                    : 'CALIBRATING AEGIS SYSTEM...',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
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
}
