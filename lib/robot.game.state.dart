// robot.game.state.dart
// Holds all mutable game state. Ported from the `gameState` object that lived
// at the top of robot.game.html. UI-only references (canvas/ctx/DOM nodes) are
// dropped; canvas dimensions and the side inputs now live here as plain fields.

class Projectile {
  double x;
  double y;
  double angle;
  double speed;
  double radius;

  Projectile({
    required this.x,
    required this.y,
    required this.angle,
    this.speed = 5,
    this.radius = 3,
  });
}

class Obstacle {
  double x;
  double y;
  double w;
  double h;

  Obstacle({required this.x, required this.y, required this.w, required this.h});

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  factory Obstacle.fromJson(Map<String, dynamic> j) => Obstacle(
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
      );
}

class Robot {
  double x;
  double y;
  double radius;
  double angle;
  double hue; // 0..360 -> HSL(hue, 60%, 70%) in the painter
  int ammo;
  bool isColliding;
  List<Projectile> projectiles;

  Robot({
    required this.x,
    required this.y,
    this.radius = 15,
    required this.angle,
    required this.hue,
    this.ammo = 100,
    this.isColliding = false,
    List<Projectile>? projectiles,
  }) : projectiles = projectiles ?? [];
}

class Player {
  double x = 200;
  double y = 150;
  double radius = 15;
  double angle = 0;
  bool visible = true;

  bool isStrafing = false;
  bool rotatingCCW = false;
  bool rotatingCW = false;
  double rotationSpeed = 0.04;

  bool movingForward = false;
  bool movingBackward = false;
  double moveSpeed = 2;

  bool isColliding = false;
  bool isHit = false;
  int numBeenHit = 0;
  double damageLevel = 0;
  bool isDead = false;
  bool flashState = false;
  int flashTimer = 0;

  String movementMode = 'manual'; // 'manual' | 'random'
  double randomTurnBias = 0;

  bool fireMode = false;
  bool evadeMode = false;
  bool huntMode = false;

  bool reloadReady = false;

  int ammo = 100;
  bool wantFire = false;
  int fireCooldown = 0;

  List<Projectile> projectiles = [];
}

class GameState {
  final Player player = Player();

  List<Obstacle> obstacles = [];

  // obstacleMode
  String obstacleOrientation = 'horz'; // 'horz' | 'vert'
  bool arrowActive = false;

  bool placingPlayer = false;

  // Fixed-length list of 5 robot slots (matches `new Array(5).fill(null)`).
  final List<Robot?> robots = List<Robot?>.filled(5, null, growable: false);
  bool robotFireMode = false;

  int stuckTimer = 0;
  bool stuckActive = false;

  // Canvas dimensions (the Width/Height inputs in the sidebar).
  double canvasWidth = 400;
  double canvasHeight = 300;

  // Obstacle size inputs.
  int side1 = 20;
  int side2 = 50;

  // ---- UI interaction state (was top-level globals in the HTML script) ----
  int? selectedObstacleIndex;
  Obstacle? draggingObstacle;
  double dragOffsetX = 0;
  double dragOffsetY = 0;
  Obstacle? previewObstacle;

  void resetRobots() {
    for (var i = 0; i < robots.length; i++) {
      robots[i] = null;
    }
    robotFireMode = false;
  }
}
