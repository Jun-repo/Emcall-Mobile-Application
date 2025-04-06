import 'dart:math';
import 'package:emcall/containers/residents/send_congratulations_email.dart';
import 'package:flutter/material.dart';

class VerifiedSuccessfullyPage extends StatefulWidget {
  final String fullName;
  final String recipientEmail;

  const VerifiedSuccessfullyPage({
    super.key,
    required this.fullName,
    required this.recipientEmail,
  });

  @override
  VerifiedSuccessfullyPageState createState() =>
      VerifiedSuccessfullyPageState();
}

class VerifiedSuccessfullyPageState extends State<VerifiedSuccessfullyPage>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final AnimationController _progressController;
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
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    setState(() {
      _isLoading = true;
      _progressController.repeat();
    });

    try {
      await sendCongratulationsEmail(widget.recipientEmail, widget.fullName);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _progressController.stop();
      });
    }
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
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Color.fromARGB(255, 245, 226, 226),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 120,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Congratulations, ${widget.fullName}!',
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
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
                    onPressed: _isLoading ? null : _handleClose,
                    child: _isLoading
                        ? SizedBox(
                            width: 26,
                            height: 26,
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, child) {
                                return CustomPaint(
                                  size: const Size(26, 26),
                                  painter: OvalProgressPainter(
                                    strokeWidth: 4,
                                    progress: _progressController.value,
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
      ..style = PaintingStyle.stroke;

    final Paint paintProgress = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

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
