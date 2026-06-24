// robot.game.storage.dart
// shared_preferences persistence. Mirrors getSaveData() / saveGame() / loadGame()
// from robot.game.html. Stores one JSON string under STORAGE_KEY, exactly like
// the original localStorage approach.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'robot.game.state.dart';

const String storageKey = 'simple_robot_shooting_game';

class Storage {
  static SharedPreferences? _prefs;

  /// Call once at startup (in main) before the game reads/writes.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Map<String, dynamic> _getSaveData(GameState gs) {
    return {
      'player': {
        'x': gs.player.x,
        'y': gs.player.y,
        'angle': gs.player.angle,
        'visible': gs.player.visible,
        'movementMode': gs.player.movementMode,
        'fireMode': gs.player.fireMode,
        'evadeMode': gs.player.evadeMode,
        'huntMode': gs.player.huntMode,
        'ammo': gs.player.ammo,
      },
      'obstacles': gs.obstacles.map((o) => o.toJson()).toList(),
      'obstacleMode': {
        'orientation': gs.obstacleOrientation,
        'arrowActive': gs.arrowActive,
      },
      'width': gs.canvasWidth,
      'height': gs.canvasHeight,
      'side1': gs.side1,
      'side2': gs.side2,
    };
  }

  /// Fire-and-forget save (the original saveGame() was synchronous).
  static void save(GameState gs) {
    _prefs?.setString(storageKey, jsonEncode(_getSaveData(gs)));
  }

  /// Returns true if a save existed and was loaded (mirrors `hasSave`).
  static bool load(GameState gs) {
    final raw = _prefs?.getString(storageKey);
    if (raw == null) return false;

    final data = jsonDecode(raw) as Map<String, dynamic>;

    final p = data['player'] as Map<String, dynamic>?;
    if (p != null) {
      if (p['x'] != null) gs.player.x = (p['x'] as num).toDouble();
      if (p['y'] != null) gs.player.y = (p['y'] as num).toDouble();
      if (p['angle'] != null) gs.player.angle = (p['angle'] as num).toDouble();
      if (p['visible'] != null) gs.player.visible = p['visible'] as bool;
      if (p['movementMode'] != null) {
        gs.player.movementMode = p['movementMode'] as String;
      }
      if (p['fireMode'] != null) gs.player.fireMode = p['fireMode'] as bool;
      if (p['evadeMode'] != null) gs.player.evadeMode = p['evadeMode'] as bool;
      if (p['huntMode'] != null) gs.player.huntMode = p['huntMode'] as bool;
      if (p['ammo'] != null) gs.player.ammo = (p['ammo'] as num).toInt();
    }

    final obs = data['obstacles'] as List<dynamic>?;
    gs.obstacles = obs == null
        ? []
        : obs
            .map((e) => Obstacle.fromJson(e as Map<String, dynamic>))
            .toList();

    final om = data['obstacleMode'] as Map<String, dynamic>?;
    if (om != null) {
      if (om['orientation'] != null) {
        gs.obstacleOrientation = om['orientation'] as String;
      }
      if (om['arrowActive'] != null) {
        gs.arrowActive = om['arrowActive'] as bool;
      }
    }

    if (data['width'] != null && data['height'] != null) {
      gs.canvasWidth = (data['width'] as num).toDouble();
      gs.canvasHeight = (data['height'] as num).toDouble();
    }

    // FORCE PLAYER TO CENTER ON LOAD (matches the original loadGame()).
    gs.player.x = gs.canvasWidth / 2;
    gs.player.y = gs.canvasHeight / 2;
    gs.player.visible = true;

    if (data['side1'] != null) gs.side1 = (data['side1'] as num).toInt();
    if (data['side2'] != null) gs.side2 = (data['side2'] as num).toInt();

    return true;
  }
}
