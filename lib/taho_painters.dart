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

class TahoCrewPainter extends CustomPainter {
  final Color color;
  const TahoCrewPainter({this.color = Colors.indigo});
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

class TahoInsertionPainter extends CustomPainter {
  final Color color;
  const TahoInsertionPainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Scale from 2.5x4 to size
    final double sx = size.width / 2.5;
    final double sy = size.height / 4.0;

    final rectPath = Path()
      ..moveTo(0 * sx, 0 * sy)
      ..lineTo(1 * sx, 0 * sy)
      ..lineTo(1 * sx, 4 * sy)
      ..lineTo(0 * sx, 4 * sy)
      ..close();
    canvas.drawPath(rectPath, paint);

    final triPath = Path()
      ..moveTo(1.5 * sx, 0 * sy)
      ..lineTo(2.5 * sx, 2 * sy)
      ..lineTo(1.5 * sx, 4 * sy)
      ..close();
    canvas.drawPath(triPath, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TahoWithdrawalPainter extends CustomPainter {
  final Color color;
  const TahoWithdrawalPainter({this.color = Colors.black});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Scale from 2.5x4 to size
    final double sx = size.width / 2.5;
    final double sy = size.height / 4.0;

    // Mirrored: Rect on the right, Triangle on the left pointing left
    final rectPath = Path()
      ..moveTo(1.5 * sx, 0 * sy)
      ..lineTo(2.5 * sx, 0 * sy)
      ..lineTo(2.5 * sx, 4 * sy)
      ..lineTo(1.5 * sx, 4 * sy)
      ..close();
    canvas.drawPath(rectPath, paint);

    final triPath = Path()
      ..moveTo(1 * sx, 0 * sy)
      ..lineTo(0 * sx, 2 * sy)
      ..lineTo(1 * sx, 4 * sy)
      ..close();
    canvas.drawPath(triPath, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
