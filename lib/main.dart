import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Построение линий'),
        ),
        body: LineDrawingScreen(),
      ),
    );
  }
}

class LineDrawingScreen extends ConsumerWidget {
  const LineDrawingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider);
    final linePainter = LinePainter(points);
    final notifier = ref.read(pointsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.undo),
            onPressed: notifier.undoLastAction,
          ),
          IconButton(
            icon: Icon(Icons.redo),
            onPressed: notifier.redoLastAction,
          ),
        ],
      ),
      body: GestureDetector(
        onTapDown: (details) {
          notifier.addPointIfUnique(details.localPosition);
        },
        onPanUpdate: (details) {
          notifier.updateLastPoint(details.localPosition);
        },
        child: CustomPaint(
          painter: linePainter,
          size: Size.infinite,
        ),
      ),
    );
  }
}

final pointsProvider = StateNotifierProvider<PointsNotifier, List<Offset>>((ref) {
  return PointsNotifier([]);
});

class PointsNotifier extends StateNotifier<List<Offset>> {
  PointsNotifier(List<Offset> state) : super(state);
  List<List<Offset>> undoList = [];
  bool isPolygonClosed = false; // флаг, указывающий, была ли фигура уже замкнута

  void addPointIfUnique(Offset newPoint) {
    if (!isPolygonClosed && (state.isEmpty || state.last != newPoint)) {
      state = [...state, newPoint];
    }
  }

  void updateLastPoint(Offset newPoint) {
    if (!isPolygonClosed && state.isNotEmpty) {
      state = List.from(state)..replaceRange(state.length - 1, state.length, [newPoint]);
    }
  }

  void undoLastAction() {
    if (state.isNotEmpty) {
      undoList.add(List.from(state));
      state = List.from(state)..removeLast();
    }
  }

  void redoLastAction() {
    if (undoList.isNotEmpty) {
      state = undoList.removeLast();
    }
  }

  void closePolygon() {
    isPolygonClosed = true;
  }
}


class LinePainter extends CustomPainter {
  final List<Offset> points;

  LinePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final Paint activePointPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2;

    final Paint pointPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4;

    final int numColumns = 12;
    final int numRows = 30;
    final double columnWidth = size.width / numColumns;
    final double rowHeight = size.height / numRows;

    // Рисуем фоновую сетку
    for (int i = 0; i < numColumns; i++) {
      for (int j = 0; j < numRows; j++) {
        Offset point = Offset((i + 0.5) * columnWidth, (j + 0.5) * rowHeight);
        canvas.drawCircle(point, 1.5, Paint()..color = Colors.blue.withOpacity(0.2));
      }
    }

    // Рисуем линии
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    // Рисуем точки
    for (Offset point in points) {
      if (points.length > 1 && point == points.first) {
        canvas.drawCircle(point, 6, Paint()..color = Colors.grey.withOpacity(0.5));
      } else {
        canvas.drawCircle(point, 5, pointPaint);
      }
    }

    // Рисуем активные точки
    if (points.length > 1) {
      final double distanceSquared = (points[0] - points[points.length - 1]).distanceSquared;
      if (distanceSquared < 100) { // Здесь 100 - это квадрат расстояния, которое считается близким
        final Paint backgroundPaint = Paint()..color = Colors.grey.withOpacity(0.5);
        final Rect backgroundRect = Rect.fromPoints(points.first, points.last);
        canvas.drawRect(backgroundRect, backgroundPaint);

        final path = Path();
        path.addPolygon(points, true); // true указывает, что многоугольник замкнутый
        canvas.drawPath(path, Paint()..color = Colors.white);

        // Рисуем длины сторон
        for (int i = 0; i < points.length - 1; i++) {
          double sideLength = (points[i + 1] - points[i]).distance;
          Offset textPosition = Offset(
            (points[i].dx + points[i + 1].dx) / 2,
            (points[i].dy + points[i + 1].dy) / 2,
          );
          TextSpan span = TextSpan(
            style: TextStyle(color: Colors.black),
            text: sideLength.toStringAsFixed(2),
          );
          TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, textPosition - Offset(tp.width / 2, tp.height / 2));
        }
        // Для последней стороны
        double lastSideLength = (points.first - points.last).distance;
        Offset lastTextPosition = Offset(
          (points.last.dx + points.first.dx) / 2,
          (points.last.dy + points.first.dy) / 2,
        );
        TextSpan lastSpan = TextSpan(
          style: TextStyle(color: Colors.black),
          text: lastSideLength.toStringAsFixed(2),
        );
        TextPainter lastTp = TextPainter(
          text: lastSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        lastTp.layout();
        lastTp.paint(canvas, lastTextPosition - Offset(lastTp.width / 2, lastTp.height / 2));
      }
    }

    // Рисуем заливку многоугольника, если он замкнут
    if (points.length > 2 && (points.first - points.last).distance < 20.0) {
      final Paint closingPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(points.last, points.first, closingPaint);

      final Paint fillPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
