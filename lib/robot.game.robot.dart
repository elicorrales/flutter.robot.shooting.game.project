// robot.game.robot.dart
// Robot AI plus the shared collision / line-of-sight / spawn helpers.
// Ported from robot.game.robot.functions.js and robot.game.helper.functions.js.

import 'dart:math';
import 'robot.game.state.dart';
import 'robot.game.sound.dart';
import 'robot.game.engine.dart' show projectileHits;

final Random _random = Random();

/* =========================
   HELPERS (was robot.game.helper.functions.js)
========================= */

bool robotOverlap(GameState gs, double x, double y, double r) {
  final dxp = x - gs.player.x;
  final dyp = y - gs.player.y;
  if (sqrt(dxp * dxp + dyp * dyp) < r + gs.player.radius) return true;

  for (final rb in gs.robots) {
    if (rb == null) continue;
    final dx = x - rb.x;
    final dy = y - rb.y;
    if (sqrt(dx * dx + dy * dy) < r + rb.radius) return true;
  }
  return false;
}

({double x, double y})? randomPosition(GameState gs, double radius) {
  var tries = 0;
  while (tries < 100) {
    final x = _random.nextDouble() * gs.canvasWidth;
    final y = _random.nextDouble() * gs.canvasHeight;

    if (!checkCollisions(gs, x, y) && !robotOverlap(gs, x, y, radius)) {
      return (x: x, y: y);
    }
    tries++;
  }
  return null;
}

bool hasLineOfSight(
    GameState gs, double x1, double y1, double x2, double y2, Robot? self) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final dist = sqrt(dx * dx + dy * dy);

  final steps = (dist / 5).floor();
  if (steps <= 0) return true;
  final stepX = dx / steps;
  final stepY = dy / steps;

  var x = x1;
  var y = y1;

  for (var i = 0; i < steps; i++) {
    x += stepX;
    y += stepY;

    for (final o in gs.obstacles) {
      if (x > o.x && x < o.x + o.w && y > o.y && y < o.y + o.h) return false;
    }

    for (final rb in gs.robots) {
      if (rb == null) continue;
      if (identical(rb, self)) continue;

      final dxr = x - rb.x;
      final dyr = y - rb.y;
      if (sqrt(dxr * dxr + dyr * dyr) < rb.radius) return false;
    }
  }

  return true;
}

bool checkCollisions(GameState gs, double nextX, double nextY, [Robot? self]) {
  final r = self != null ? self.radius : gs.player.radius;

  if (nextX - r < 0 ||
      nextX + r > gs.canvasWidth ||
      nextY - r < 0 ||
      nextY + r > gs.canvasHeight) {
    return true;
  }

  for (final o in gs.obstacles) {
    final closestX = max(o.x, min(nextX, o.x + o.w));
    final closestY = max(o.y, min(nextY, o.y + o.h));

    final dx = nextX - closestX;
    final dy = nextY - closestY;

    if (dx * dx + dy * dy < r * r) return true;
  }

  for (final rb in gs.robots) {
    if (rb == null) continue;
    if (identical(rb, self)) continue;

    final dx = nextX - rb.x;
    final dy = nextY - rb.y;
    if (sqrt(dx * dx + dy * dy) < r + rb.radius) return true;
  }

  // A robot also collides with the player (self != player here).
  if (self != null) {
    final dxp = nextX - gs.player.x;
    final dyp = nextY - gs.player.y;
    if (sqrt(dxp * dxp + dyp * dyp) < r + gs.player.radius) return true;
  }

  return false;
}

/* =========================
   ROBOT AI (was robot.game.robot.functions.js)
========================= */

Robot? createRobot(GameState gs) {
  final pos = randomPosition(gs, 15);
  if (pos == null) return null;

  return Robot(
    x: pos.x,
    y: pos.y,
    radius: 15,
    angle: _random.nextDouble() * pi * 2,
    hue: _random.nextDouble() * 360,
    ammo: 100,
  );
}

void updateRobots(GameState gs) {
  for (final rb in gs.robots) {
    if (rb == null) continue;

    final seesPlayer = hasLineOfSight(
        gs, rb.x, rb.y, gs.player.x, gs.player.y, rb);

    if (seesPlayer && gs.player.visible) {
      rb.angle = atan2(gs.player.y - rb.y, gs.player.x - rb.x);

      if (gs.robotFireMode && rb.ammo > 0) {
        // Fire occasionally so it isn't a solid line of bullets.
        if (_random.nextDouble() < 0.05) {
          rb.projectiles.add(Projectile(
            x: rb.x + cos(rb.angle) * (rb.radius + 5),
            y: rb.y + sin(rb.angle) * (rb.radius + 5),
            angle: rb.angle,
            speed: 5,
            radius: 3,
          ));
          SoundSystem.fire();
          rb.ammo--;
        }
      }
    } else {
      rb.angle += (_random.nextDouble() - 0.5) * 0.1;
    }

    final nextX = rb.x + cos(rb.angle) * 2;
    final nextY = rb.y + sin(rb.angle) * 2;

    if (!checkCollisions(gs, nextX, nextY, rb)) {
      rb.x = nextX;
      rb.y = nextY;
      rb.isColliding = false;
    } else {
      rb.isColliding = true;

      final leftTry = rb.angle - 0.4;
      final rightTry = rb.angle + 0.4;

      final lx = rb.x + cos(leftTry) * 2;
      final ly = rb.y + sin(leftTry) * 2;
      final rx = rb.x + cos(rightTry) * 2;
      final ry = rb.y + sin(rightTry) * 2;

      if (!checkCollisions(gs, lx, ly, rb)) {
        rb.angle = leftTry;
      } else if (!checkCollisions(gs, rx, ry, rb)) {
        rb.angle = rightTry;
      } else {
        rb.angle += (_random.nextDouble() - 0.5) * 1.2;
      }
    }

    rb.projectiles.removeWhere((p) {
      p.x += cos(p.angle) * p.speed;
      p.y += sin(p.angle) * p.speed;
      return projectileHits(gs, p, rb);
    });
  }
}
