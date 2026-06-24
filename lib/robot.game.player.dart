// robot.game.player.dart
// Player movement, manual + random AI, fire system, and the cloak/appear/relocate
// actions. Ported from robot.game.player.functions.js. The original called
// button .click() handlers for cloak/appear during auto-relocate; those are now
// the plain functions doCloak()/doAppear() (also used by the sidebar buttons).

import 'dart:async';
import 'dart:math';
import 'robot.game.state.dart';
import 'robot.game.sound.dart';
import 'robot.game.storage.dart';
import 'robot.game.robot.dart';

final Random _random = Random();

typedef Ray = ({double distance, bool hitRobot, int? robotId});

/* =========================
   MOVEMENT PRIMITIVES
========================= */

void moveForward(GameState gs, [double? targetAngle]) {
  final angle = targetAngle ?? gs.player.angle;
  gs.player.x += cos(angle) * gs.player.moveSpeed;
  gs.player.y += sin(angle) * gs.player.moveSpeed;
}

void moveBackward(GameState gs) {
  gs.player.x -= cos(gs.player.angle) * gs.player.moveSpeed;
  gs.player.y -= sin(gs.player.angle) * gs.player.moveSpeed;
}

void rotateLeft(GameState gs) => gs.player.angle -= gs.player.rotationSpeed;
void rotateRight(GameState gs) => gs.player.angle += gs.player.rotationSpeed;

void slideLeft(GameState gs, [double? targetAngle]) {
  final angle = targetAngle ?? gs.player.angle;
  gs.player.x += cos(angle - pi / 2) * gs.player.moveSpeed;
  gs.player.y += sin(angle - pi / 2) * gs.player.moveSpeed;
}

void slideRight(GameState gs, [double? targetAngle]) {
  final angle = targetAngle ?? gs.player.angle;
  gs.player.x += cos(angle + pi / 2) * gs.player.moveSpeed;
  gs.player.y += sin(angle + pi / 2) * gs.player.moveSpeed;
}

/* =========================
   MANUAL MODE
========================= */

void updatePlayerManualMovementMode(GameState gs) {
  final oldX = gs.player.x;
  final oldY = gs.player.y;

  if (gs.player.isStrafing) {
    if (gs.player.rotatingCCW) slideLeft(gs);
    if (gs.player.rotatingCW) slideRight(gs);
  } else {
    if (gs.player.rotatingCCW) rotateLeft(gs);
    if (gs.player.rotatingCW) rotateRight(gs);
  }

  if (gs.player.movingForward) moveForward(gs);
  if (gs.player.movingBackward) moveBackward(gs);

  if (checkCollisions(gs, gs.player.x, gs.player.y)) {
    gs.player.isColliding = true;
    gs.player.x = oldX;
    gs.player.y = oldY;
  } else {
    gs.player.isColliding = false;
  }
}

/* =========================
   RAYCAST + RANDOM-MODE AI
========================= */

Ray playerRayDistance(GameState gs, double angle) {
  const step = 4.0;
  var dist = 0.0;
  var x = gs.player.x;
  var y = gs.player.y;

  while (true) {
    x += cos(angle) * step;
    y += sin(angle) * step;
    dist += step;

    if (x < 0 || x > gs.canvasWidth || y < 0 || y > gs.canvasHeight) {
      return (distance: dist, hitRobot: false, robotId: null);
    }

    for (final o in gs.obstacles) {
      if (x > o.x && x < o.x + o.w && y > o.y && y < o.y + o.h) {
        return (distance: dist, hitRobot: false, robotId: null);
      }
    }

    for (var i = 0; i < gs.robots.length; i++) {
      final rb = gs.robots[i];
      if (rb == null) continue;
      final dx = x - rb.x;
      final dy = y - rb.y;
      if (dx * dx + dy * dy < rb.radius * rb.radius) {
        return (distance: dist, hitRobot: true, robotId: i);
      }
    }
  }
}

void handleRobotEngagement(GameState gs, Ray best) {
  final id = best.robotId;
  if (id == null) return;
  final rb = gs.robots[id];
  if (rb == null) return;

  final dx = rb.x - gs.player.x;
  final dy = rb.y - gs.player.y;
  final targetAngle = atan2(dy, dx);

  final alertness = gs.player.huntMode ? 0.4 : 0.2;
  gs.player.angle += (targetAngle - gs.player.angle) * alertness;

  gs.player.wantFire = true;
}

void handleNavigation(GameState gs, Ray forward, Ray left, Ray right) {
  var targetAngle = gs.player.angle;

  if (left.distance > forward.distance && left.distance > right.distance) {
    targetAngle = gs.player.angle - pi / 6;
  } else if (right.distance > forward.distance &&
      right.distance > left.distance) {
    targetAngle = gs.player.angle + pi / 6;
  }

  var bias = 0.0;
  if (left.distance < right.distance) {
    bias = 0.08;
  } else if (right.distance < left.distance) {
    bias = -0.08;
  }

  gs.player.angle += (targetAngle - gs.player.angle) * 0.2 + bias;
}

void handleMovementStep(GameState gs) {
  final nextX = gs.player.x + cos(gs.player.angle) * gs.player.moveSpeed;
  final nextY = gs.player.y + sin(gs.player.angle) * gs.player.moveSpeed;

  if (checkCollisions(gs, nextX, nextY)) {
    gs.player.isColliding = true;

    final leftTry = gs.player.angle - 0.4;
    final rightTry = gs.player.angle + 0.4;

    final lx = gs.player.x + cos(leftTry) * gs.player.moveSpeed;
    final ly = gs.player.y + sin(leftTry) * gs.player.moveSpeed;
    final rx = gs.player.x + cos(rightTry) * gs.player.moveSpeed;
    final ry = gs.player.y + sin(rightTry) * gs.player.moveSpeed;

    if (!checkCollisions(gs, lx, ly)) {
      gs.player.angle = leftTry;
    } else if (!checkCollisions(gs, rx, ry)) {
      gs.player.angle = rightTry;
    } else {
      gs.player.angle += (_random.nextDouble() - 0.5) * 1.2;
    }
  } else {
    gs.player.isColliding = false;
    moveForward(gs, gs.player.angle);
  }
}

bool handleEvade(GameState gs, Ray forward, Ray left, Ray right) {
  // Obstacle pre-avoidance (Evade only).
  final buffer = gs.player.radius + 25;
  final aheadX = gs.player.x + cos(gs.player.angle) * buffer;
  final aheadY = gs.player.y + sin(gs.player.angle) * buffer;

  var hitAhead = false;
  for (final o in gs.obstacles) {
    if (aheadX > o.x &&
        aheadX < o.x + o.w &&
        aheadY > o.y &&
        aheadY < o.y + o.h) {
      hitAhead = true;
      break;
    }
  }

  if (hitAhead) {
    if (left.distance > right.distance) {
      gs.player.angle -= gs.player.rotationSpeed * 6;
    } else {
      gs.player.angle += gs.player.rotationSpeed * 6;
    }
    return true;
  }

  // Continuous boundary/obstacle pressure.
  const minDist = 60.0;
  final fBias = max(0.0, (minDist - forward.distance) / minDist);
  final lBias = max(0.0, (minDist - left.distance) / minDist);
  final rBias = max(0.0, (minDist - right.distance) / minDist);

  if (fBias > 0 || lBias > 0 || rBias > 0) {
    final leftScore = lBias + (forward.distance > left.distance ? 0.2 : 0);
    final rightScore = rBias + (forward.distance > right.distance ? 0.2 : 0);

    if (leftScore > rightScore) {
      gs.player.angle += gs.player.rotationSpeed * (1 + leftScore * 5);
    } else {
      gs.player.angle -= gs.player.rotationSpeed * (1 + rightScore * 5);
    }
    return true;
  }

  final fR = forward.hitRobot;
  final lR = left.hitRobot;
  final rR = right.hitRobot;

  if (fR && lR && !rR) {
    gs.player.angle += gs.player.rotationSpeed * 2;
    return true;
  }
  if (fR && rR && !lR) {
    gs.player.angle -= gs.player.rotationSpeed * 2;
    return true;
  }
  if (lR && rR && !fR) {
    return false; // escape gap; let normal movement handle it
  }
  if (fR && lR && rR) {
    gs.player.angle += (_random.nextDouble() - 0.5) * 1.5;
    return true;
  }
  if (fR) {
    if (left.distance > right.distance) {
      gs.player.angle -= gs.player.rotationSpeed;
    } else {
      gs.player.angle += gs.player.rotationSpeed;
    }
    return true;
  }
  if (lR) {
    gs.player.angle += gs.player.rotationSpeed * 9;
    return true;
  }
  if (rR) {
    gs.player.angle -= gs.player.rotationSpeed * 9;
    return true;
  }

  return false;
}

void updatePlayerRandomMovementMode(GameState gs) {
  final forward = playerRayDistance(gs, gs.player.angle);
  final left = playerRayDistance(gs, gs.player.angle - pi / 6);
  final right = playerRayDistance(gs, gs.player.angle + pi / 6);

  final rays = <({double dir, Ray data})>[
    (dir: 0, data: forward),
    (dir: -pi / 6, data: left),
    (dir: pi / 6, data: right),
  ];

  Ray? best;
  for (final r in rays) {
    if (r.data.hitRobot) {
      if (best == null || r.data.distance < best.distance) {
        best = r.data;
      }
    }
  }

  if (gs.player.evadeMode) {
    final didEvade = handleEvade(gs, forward, left, right);
    if (!didEvade) {
      handleNavigation(gs, forward, left, right);
    }
  } else {
    if (best != null && (gs.player.fireMode || gs.player.huntMode)) {
      handleRobotEngagement(gs, best);
    } else if (gs.player.huntMode) {
      gs.player.angle +=
          sin(DateTime.now().millisecondsSinceEpoch / 150) * 0.2;
    }
    handleNavigation(gs, forward, left, right);
  }

  handleMovementStep(gs);

  if (gs.player.isColliding) {
    gs.stuckTimer++;
    if (gs.stuckTimer > 60 && !gs.stuckActive) {
      gs.stuckActive = true;
      triggerAutoRelocate(gs);
      Timer(const Duration(milliseconds: 2500), () {
        gs.stuckActive = false;
        gs.stuckTimer = 0;
      });
    }
  } else {
    gs.stuckTimer = 0;
  }
}

/* =========================
   TOP-LEVEL UPDATE + FIRE SYSTEM
========================= */

void updatePlayer(GameState gs) {
  if (gs.player.isDead) return;

  updateFireSystem(gs);

  if (gs.player.movementMode == 'manual') {
    updatePlayerManualMovementMode(gs);
  } else {
    updatePlayerRandomMovementMode(gs);
  }
}

void updateFireSystem(GameState gs) {
  if (gs.player.fireCooldown > 0) gs.player.fireCooldown--;

  if (gs.player.wantFire) {
    firePlayerProjectile(gs);
    gs.player.wantFire = false;
  }
}

void firePlayerProjectile(GameState gs) {
  if (gs.player.ammo <= 0) return;
  if (gs.player.fireCooldown > 0) return;

  final startX = gs.player.x + cos(gs.player.angle) * (gs.player.radius + 6);
  final startY = gs.player.y + sin(gs.player.angle) * (gs.player.radius + 6);

  gs.player.projectiles.add(Projectile(
    x: startX,
    y: startY,
    angle: gs.player.angle,
    speed: 5,
    radius: 3,
  ));

  SoundSystem.fire();

  gs.player.ammo--;
  gs.player.fireCooldown = 6;
}

/* =========================
   CLOAK / APPEAR / RELOCATE ACTIONS
========================= */

void doCloak(GameState gs) {
  gs.player.visible = false;
  gs.placingPlayer = false;
  gs.arrowActive = false;
  Storage.save(gs);
}

void doAppear(GameState gs) {
  gs.player.isDead = false;
  gs.player.numBeenHit = 0;
  gs.player.damageLevel = 0;
  gs.placingPlayer = true;
  Storage.save(gs);
}

void relocatePlayerAvoiding(GameState gs, double oldX, double oldY) {
  var tries = 0;
  while (tries < 200) {
    final pos = randomPosition(gs, gs.player.radius);
    if (pos == null) break;

    final dx = pos.x - oldX;
    final dy = pos.y - oldY;

    if (sqrt(dx * dx + dy * dy) > gs.player.radius * 4) {
      gs.player.x = pos.x;
      gs.player.y = pos.y;
      gs.player.visible = true;
      gs.placingPlayer = false;
      return;
    }
    tries++;
  }
}

void triggerAutoRelocate(GameState gs) {
  final oldX = gs.player.x;
  final oldY = gs.player.y;

  doCloak(gs);

  Timer(const Duration(milliseconds: 1000), () {
    doAppear(gs);
    Timer(const Duration(milliseconds: 1000), () {
      relocatePlayerAvoiding(gs, oldX, oldY);
    });
  });
}
