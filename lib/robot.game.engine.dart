// robot.game.engine.dart
// The per-frame update (was animate() + requestAnimationFrame), projectileHits(),
// resetCanvas(), and the ammo/flash bookkeeping. The actual frame driver is a
// Ticker in robot.game.ui.dart, which calls tick() each frame and then repaints.

import 'dart:async';
import 'dart:math';
import 'robot.game.state.dart';
import 'robot.game.storage.dart';
import 'robot.game.player.dart';
import 'robot.game.robot.dart';

/// Returns true when the projectile should be removed. `attacker` is the robot
/// that fired it (or null for player shots), used for the hunt-mode "sense the
/// source" reaction.
bool projectileHits(GameState gs, Projectile p, [Robot? attacker]) {
  // 1. Wall collision.
  if (p.x < 0 || p.x > gs.canvasWidth || p.y < 0 || p.y > gs.canvasHeight) {
    return true;
  }

  // 2. Obstacle collision.
  for (final o in gs.obstacles) {
    if (p.x > o.x && p.x < o.x + o.w && p.y > o.y && p.y < o.y + o.h) {
      return true;
    }
  }

  // 3. Hit the player.
  if (gs.player.visible) {
    final dx = p.x - gs.player.x;
    final dy = p.y - gs.player.y;
    final distSq = dx * dx + dy * dy;

    if (distSq < gs.player.radius * gs.player.radius) {
      gs.player.numBeenHit++;
      gs.player.damageLevel = min(1.0, gs.player.damageLevel + 0.2);
      gs.player.isHit = true;

      // If hit by a robot while hunting, immediately face the source.
      if (attacker != null && gs.player.huntMode) {
        gs.player.angle =
            atan2(attacker.y - gs.player.y, attacker.x - gs.player.x);
      }

      if (gs.player.numBeenHit >= 5) {
        gs.player.isDead = true;
        gs.player.visible = false;
      }

      Timer(const Duration(milliseconds: 150), () {
        gs.player.isHit = false;
      });
      return true;
    }
  }

  // 4. Hit a robot (distSq < 400 -> within 20px). Removing the robot replaces
  // the original "click the robot button to toggle it off".
  for (var i = 0; i < gs.robots.length; i++) {
    final rb = gs.robots[i];
    if (rb == null) continue;

    final dx = p.x - rb.x;
    final dy = p.y - rb.y;
    if (dx * dx + dy * dy < 400) {
      gs.robots[i] = null;
      Storage.save(gs);
      return true;
    }
  }

  return false;
}

/// Out-of-ammo disables firing modes (the visual disabling is done in the UI).
void updateFireButtonState(GameState gs) {
  if (gs.player.ammo <= 0) {
    gs.player.fireMode = false;
    gs.player.huntMode = false;
  }
}

void _updateFlash(Player p) {
  final shouldFlash = p.isColliding || p.isHit;
  if (shouldFlash) {
    p.flashTimer++;
    if (p.flashTimer % 10 == 0) {
      p.flashState = !p.flashState;
    }
  } else {
    p.flashState = false;
    p.flashTimer = 0;
  }
}

/// One frame of simulation (was animate(), minus the draw + rAF recursion).
void tick(GameState gs) {
  updatePlayer(gs);

  gs.player.projectiles.removeWhere((p) {
    p.x += cos(p.angle) * p.speed;
    p.y += sin(p.angle) * p.speed;
    return projectileHits(gs, p, null);
  });

  updateRobots(gs);
  updateFireButtonState(gs);
  _updateFlash(gs.player);
}

/// Full reset to defaults at the current canvas size. Combines the original
/// resetCanvas() and its later "reset hook" (which also cleared robots).
void resetCanvas(GameState gs) {
  gs.player.x = gs.canvasWidth / 2;
  gs.player.y = gs.canvasHeight / 2;
  gs.player.angle = 0;
  gs.player.visible = true;
  gs.player.isDead = false;
  gs.player.numBeenHit = 0;
  gs.player.damageLevel = 0;

  gs.obstacles = [];
  gs.player.projectiles = [];
  gs.player.ammo = 100;

  gs.selectedObstacleIndex = null;
  gs.previewObstacle = null;
  gs.draggingObstacle = null;

  gs.resetRobots();

  Storage.save(gs);
}
