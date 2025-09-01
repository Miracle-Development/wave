import 'package:flutter/material.dart';

/// Универсальный painter для четырёхугольника (трапеции/параллелограмма и т.д.)
/// points: список из 4 Offset-ов.
///   - если normalized == true, то каждая точка интерпретируется как (dx * width, dy * height)
///   - порядок точек: верхний левый, верхний правый, нижний правый, нижний левый
/// colors: градиент (2+ цвета)
/// drawShadow: рисует тень под фигурой
class QuadPainter extends CustomPainter {
  final List<Offset> points;
  final bool normalized;
  final Color color;
  final bool drawShadow;
  final double shadowElevation;
  final double cornerRadius; // если > 0 — скругляет углы (аппроксимация)
  final bool fill; // если false — рисует только stroke
  final StrokeCap strokeCap;
  final double strokeWidth;
  final Color strokeColor;

  QuadPainter({
    required this.points,
    this.normalized = true,
    required this.color,
    this.drawShadow = true,
    this.shadowElevation = 8.0,
    this.cornerRadius = 0.0,
    this.fill = true,
    this.strokeCap = StrokeCap.butt,
    this.strokeWidth = 1.0,
    this.strokeColor = Colors.transparent,
  }) : assert(points.length == 4, 'points must contain exactly 4 offsets');

  @override
  void paint(Canvas canvas, Size size) {
    // преобразуем (если нужно) нормализованные координаты в пиксели
    final pts = points.map((p) {
      return normalized ? Offset(p.dx * size.width, p.dy * size.height) : p;
    }).toList();

    // порядок: p0(topLeft), p1(topRight), p2(bottomRight), p3(bottomLeft)
    final p0 = pts[0];
    final p1 = pts[1];
    final p2 = pts[2];
    final p3 = pts[3];

    final path = Path();
    if (cornerRadius > 0.0) {
      // простая аппроксимация скруглённых углов через addRRect с bbox — но для произв. четырёхугольника
      // сделаем локальную методику: строим Path с arcToPoint на каждой вершине
      final r = cornerRadius;
      // move to p0 offset a bit towards p1/p3
      Offset v01 = (p1 - p0);
      Offset v03 = (p3 - p0);
      Offset a0 = p0 + _normalize(v01) * r + _normalize(v03) * r;
      path.moveTo(a0.dx, a0.dy);

      // p1
      Offset v12 = (p2 - p1);
      Offset v10 = (p0 - p1);
      Offset a1 = p1 + _normalize(v12) * r + _normalize(v10) * r;
      path.lineTo(a1.dx, a1.dy);

      // p2
      Offset v23 = (p3 - p2);
      Offset v21 = (p1 - p2);
      Offset a2 = p2 + _normalize(v23) * r + _normalize(v21) * r;
      path.lineTo(a2.dx, a2.dy);

      // p3
      Offset v30 = (p0 - p3);
      Offset v32 = (p2 - p3);
      Offset a3 = p3 + _normalize(v30) * r + _normalize(v32) * r;
      path.lineTo(a3.dx, a3.dy);

      path.close();
      // NOTE: это простая аппроксимация — для идеальных скруглений можно строить кривые; но обычно достаточно.
    } else {
      path.addPolygon([p0, p1, p2, p3], true);
    }

    // тень (если нужно)
    if (drawShadow) {
      canvas.drawShadow(
          path, Colors.black.withOpacity(0.6), shadowElevation, true);
    }

    if (fill) {
      // градиентная заливка по bounds пути
      // final bounds = path.getBounds();
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..color = color;
      // ..shader = LinearGradient(
      //   begin: Alignment.centerLeft,
      //   end: Alignment.centerRight,
      //   color: color,
      // ).createShader(bounds);
      canvas.drawPath(path, paint);
    }

    // опциональная обводка
    if (strokeColor != Colors.transparent && strokeWidth > 0) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = strokeCap
        ..color = strokeColor;
      canvas.drawPath(path, strokePaint);
    }
  }

  // вспомогательная норма
  Offset _normalize(Offset v) {
    final len = v.distance;
    if (len == 0) return Offset.zero;
    return v / len;
  }

  @override
  bool shouldRepaint(covariant QuadPainter old) {
    return old.points != points ||
        old.normalized != normalized ||
        old.color != color ||
        old.cornerRadius != cornerRadius ||
        old.drawShadow != drawShadow;
  }
}
