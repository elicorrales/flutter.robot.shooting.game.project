// robot.game.painter.dart
// CustomPainter equivalent of draw() + drawObstacles/drawProjectiles/drawPlayer/
// drawRobots. Pure: it only reads GameState (the per-frame flash bookkeeping was
// moved into the engine tick).

import 'dart:math';
import 'package:flutter/material.dart';
import 'robot.game.state.dart';

class GamePainter extends CustomPainter {
  final GameState gs;
  GamePainter(this.gs);

  @override
  void paint(Canvas canvas, Size size) {
    // White play area (the canvas background in the original CSS).
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bg);

    _drawObstacles(canvas);

    if (gs.player.visible) {
      _drawProjectiles(canvas);
      _drawPlayer(canvas);
    }

    _drawRobots(canvas);
  }

  void _drawObstacles(Canvas canvas) {
    for (var i = 0; i < gs.obstacles.length; i++) {
      final o = gs.obstacles[i];
      final Paint paint = Paint();
      if (identical(o, gs.draggingObstacle)) {
        paint.color = const Color.fromRGBO(136, 136, 136, 0.5);
      } else if (gs.selectedObstacleIndex == i) {
        paint.color = const Color(0xFFFF4444);
      } else {
        paint.color = const Color(0xFF888888);
      }
      canvas.drawRect(Rect.fromLTWH(o.x, o.y, o.w, o.h), paint);
    }

    final preview = gs.previewObstacle;
    if (preview != null) {
      canvas.drawRect(
        Rect.fromLTWH(preview.x, preview.y, preview.w, preview.h),
        Paint()..color = const Color.fromRGBO(136, 136, 136, 0.5),
      );
    }
  }

  void _drawProjectiles(Canvas canvas) {
    final paint = Paint()..color = Colors.black;
    for (final p in gs.player.projectiles) {
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  void _drawPlayer(Canvas canvas) {
    final p = gs.player;

    final colorVal = (255 * (1 - p.damageLevel)).floor().clamp(0, 255);
    final grey = Color.fromARGB(255, colorVal, colorVal, colorVal);

    final shouldFlash = p.isColliding || p.isHit;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = (shouldFlash && p.flashState) ? const Color(0xFFFF0000) : grey;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black;

    canvas.drawCircle(Offset(p.x, p.y), p.radius, fill);
    canvas.drawCircle(Offset(p.x, p.y), p.radius, stroke);

    // Gun barrel.
    final endX = p.x + cos(p.angle) * (p.radius + 5);
    final endY = p.y + sin(p.angle) * (p.radius + 5);
    final gun = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;
    canvas.drawLine(Offset(p.x, p.y), Offset(endX, endY), gun);
  }

  void _drawRobots(Canvas canvas) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black;
    final bullet = Paint()..color = Colors.black;

    for (final rb in gs.robots) {
      if (rb == null) continue;

      final fill = Paint()
        ..color = HSLColor.fromAHSL(1.0, rb.hue, 0.6, 0.7).toColor();

      canvas.drawCircle(Offset(rb.x, rb.y), rb.radius, fill);
      canvas.drawCircle(Offset(rb.x, rb.y), rb.radius, stroke);

      final ex = rb.x + cos(rb.angle) * (rb.radius + 5);
      final ey = rb.y + sin(rb.angle) * (rb.radius + 5);
      canvas.drawLine(Offset(rb.x, rb.y), Offset(ex, ey), stroke);

      for (final p in rb.projectiles) {
        canvas.drawCircle(Offset(p.x, p.y), p.radius, bullet);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
