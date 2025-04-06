import 'dart:math';
import 'package:flutter/material.dart';

class OrgVerifiedSuccessfullyPage extends StatefulWidget {
  final String publicOrgName;

  const OrgVerifiedSuccessfullyPage({
    super.key,
    required this.publicOrgName,
  });

  @override
  OrgVerifiedSuccessfullyPageState createState() =>
      OrgVerifiedSuccessfullyPageState();
}

class OrgVerifiedSuccessfullyPageState
    extends State<OrgVerifiedSuccessfullyPage> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.bounceOut,
    );
    _controller.forward();

    _progressController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _progressAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_progressController);
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _onClosePressed() {
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.redAccent,
      body: Center(
        child: ScaleTransition(
          scale: _animation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.red, width: 0.7),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 20),
                Text(
                  'Congratulations, ${widget.publicOrgName}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your account has been successfully verified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(46),
                      ),
                    ),
                    onPressed: _isLoading ? null : _onClosePressed,
                    child: _isLoading
                        ? SizedBox(
                            width: 30,
                            height: 30,
                            child: AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: OvalProgressPainter(
                                    strokeWidth: 4,
                                    progress: _progressAnimation.value,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          )
                        : const Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontFamily: "Gilroy",
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OvalProgressPainter extends CustomPainter {
  final double strokeWidth;
  final double progress;
  final Color color;

  OvalProgressPainter({
    required this.strokeWidth,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paintBackground = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint paintProgress = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Rect ovalRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawArc(ovalRect, 0, pi * 2, false, paintBackground);
    canvas.drawArc(ovalRect, -pi / 2, pi * 2 * progress, false, paintProgress);
  }

  @override
  bool shouldRepaint(OvalProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
