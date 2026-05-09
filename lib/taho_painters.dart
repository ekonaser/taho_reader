import 'package:flutter/material.dart';

class TahoDrivePainter extends CustomPainter {
  final Color color;
  const TahoDrivePainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.125;
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.4, paint);
    final fillPaint = Paint()..color = color;
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.1, fillPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TahoWorkPainter extends CustomPainter {
  final Color color;
  const TahoWorkPainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;

    void drawHammer(Canvas canvas, bool mirrored) {
      canvas.save();
      canvas.translate(w / 2, h / 2);
      if (mirrored) canvas.scale(-1, 1);
      canvas.rotate(-0.785);
      canvas.drawRect(Rect.fromLTWH(-w * 0.06, -h * 0.4, w * 0.12, h * 0.9), paint);
      canvas.drawRect(Rect.fromLTWH(-w * 0.3, -h * 0.5, w * 0.6, h * 0.2), paint);
      canvas.restore();
    }
    drawHammer(canvas, false);
    drawHammer(canvas, true);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TahoAvailabilityPainter extends CustomPainter {
  final Color color;
  const TahoAvailabilityPainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15;
    final rect = Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.8, size.height * 0.8);
    canvas.drawRect(rect, paint);
    canvas.drawLine(rect.bottomLeft, rect.topRight, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TahoRestPainter extends CustomPainter {
  final Color color;
  const TahoRestPainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = size.width * 0.15;
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width * 0.2, size.height * 0.2);
    path.moveTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height * 0.8);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TahoSessionPainter extends CustomPainter {
  final Color color;
  const TahoSessionPainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TahoCrewPainter extends CustomPainter {
  final Color color;
  const TahoCrewPainter({this.color = Colors.red});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
