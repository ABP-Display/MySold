import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Generated locally, with a white quiet zone for every application theme.
class TotpQrCode extends StatelessWidget {
  final String uri;
  const TotpQrCode({super.key, required this.uri});

  @override
  Widget build(BuildContext context) => Align(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(painter: _TotpQrPainter(uri)),
      ),
    ),
  );
}

class _TotpQrPainter extends CustomPainter {
  final String data;
  final QrImage image;
  _TotpQrPainter(this.data)
    : image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
      );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final module = size.width / (image.moduleCount + 8);
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var y = 0; y < image.moduleCount; y++) {
      for (var x = 0; x < image.moduleCount; x++) {
        if (image.isDark(y, x)) {
          canvas.drawRect(
            Rect.fromLTWH((x + 4) * module, (y + 4) * module, module, module),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TotpQrPainter oldDelegate) =>
      oldDelegate.data != data;
}
