import 'package:flutter/material.dart';
import 'package:conduit/utils/styles.dart';

/// The standard QR viewfinder drawn over a full-bleed camera preview: a rounded
/// square window framed by rounded corner brackets, with a hint just below it.
///
/// The window is a square inset 16px from each side — matching the width of the
/// QR codes we display — and uses the app's shared [cornerRadiusValue] so the
/// brackets match every other rounded corner in the app.
class ScannerOverlay extends StatelessWidget {
  final String hint;

  const ScannerOverlay({super.key, this.hint = 'Scan QR'});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const inset = 16.0;
        final side = constraints.maxWidth - inset * 2;
        final top = (constraints.maxHeight - side) / 2;
        final window = Rect.fromLTWH(inset, top, side, side);

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(window: window),
              ),
            ),
            Positioned(
              top: window.bottom + 24,
              left: 0,
              right: 0,
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: mediumStyle.copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect window;

  _ScannerOverlayPainter({required this.window});

  @override
  void paint(Canvas canvas, Size size) {
    const radius = cornerRadiusValue;

    // Rounded L-brackets on each corner, matching the window's radius.
    const arm = 28.0;
    final r = radius.x;
    final bracket = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final corners = Path()
      // top-left
      ..moveTo(window.left, window.top + arm)
      ..lineTo(window.left, window.top + r)
      ..arcToPoint(Offset(window.left + r, window.top), radius: radius)
      ..lineTo(window.left + arm, window.top)
      // top-right
      ..moveTo(window.right - arm, window.top)
      ..lineTo(window.right - r, window.top)
      ..arcToPoint(Offset(window.right, window.top + r), radius: radius)
      ..lineTo(window.right, window.top + arm)
      // bottom-right
      ..moveTo(window.right, window.bottom - arm)
      ..lineTo(window.right, window.bottom - r)
      ..arcToPoint(Offset(window.right - r, window.bottom), radius: radius)
      ..lineTo(window.right - arm, window.bottom)
      // bottom-left
      ..moveTo(window.left + arm, window.bottom)
      ..lineTo(window.left + r, window.bottom)
      ..arcToPoint(Offset(window.left, window.bottom - r), radius: radius)
      ..lineTo(window.left, window.bottom - arm);
    canvas.drawPath(corners, bracket);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter oldDelegate) =>
      oldDelegate.window != window;
}
