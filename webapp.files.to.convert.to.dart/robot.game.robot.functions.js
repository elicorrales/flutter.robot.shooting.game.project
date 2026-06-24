//robot.game.robot.functions.js

function createRobot(gameState) {
  const pos = randomPosition(gameState, 15);
  if (!pos) return null;

  return {
    x: pos.x,
    y: pos.y,
    radius: 15,
    angle: Math.random() * Math.PI * 2,
    color: `hsl(${Math.random()*360},60%,70%)`,
    projectiles: [],
    ammo: 100,
    isColliding: false
  };
}

function updateRobots(gameState) {
  gameState.robots.forEach(rb => {
    if (!rb) return;

    const seesPlayer = hasLineOfSight(gameState, rb.x, rb.y, gameState.player.x, gameState.player.y, rb);

    if (seesPlayer && gameState.player.visible) {
      rb.angle = Math.atan2(gameState.player.y - rb.y, gameState.player.x - rb.x);

      // --- ADD THIS FIRING TRIGGER ---
      // If global robot fire mode is on and robot has ammo
      if (gameState.robotFireMode && rb.ammo > 0) {
        // Fire occasionally (e.g., 5% chance per frame to avoid a solid line of bullets)
        if (Math.random() < 0.05) {
          rb.projectiles.push({
            x: rb.x + Math.cos(rb.angle) * (rb.radius + 5),
            y: rb.y + Math.sin(rb.angle) * (rb.radius + 5),
            angle: rb.angle,
            speed: 5,
            radius: 3
          });
          
          SoundSystem.fire();
          
          rb.ammo--;
        }
      }
      // -------------------------------

    } else {
      /* existing drift */
      rb.angle += (Math.random() - 0.5) * 0.1;
    }

    let nextX = rb.x + Math.cos(rb.angle) * 2;
    let nextY = rb.y + Math.sin(rb.angle) * 2;

    // FIX: pass rb as "self"
    if (!checkCollisions(gameState, nextX, nextY, rb)) {
      rb.x = nextX;
      rb.y = nextY;
      rb.isColliding = false;
    } else {
      rb.isColliding = true;

      // same escape logic style as player
      const leftTry = rb.angle - 0.4;
      const rightTry = rb.angle + 0.4;

      const lx = rb.x + Math.cos(leftTry) * 2;
      const ly = rb.y + Math.sin(leftTry) * 2;

      const rx = rb.x + Math.cos(rightTry) * 2;
      const ry = rb.y + Math.sin(rightTry) * 2;

      // FIX: pass rb as "self"
      if (!checkCollisions(gameState, lx, ly, rb)) {
        rb.angle = leftTry;
      } else if (!checkCollisions(gameState, rx, ry, rb)) {
        rb.angle = rightTry;
      } else {
        rb.angle += (Math.random() - 0.5) * 1.2;
      }
    }

    // projectile update (kept, but no firing trigger change yet)
    rb.projectiles = rb.projectiles.filter(p => {

      p.x += Math.cos(p.angle) * p.speed;
      p.y += Math.sin(p.angle) * p.speed;

      return !projectileHits(p, rb);
    });
  });
}

function drawRobots(gameState) {
  gameState.robots.forEach(rb => {
    if (!rb) return;

    gameState.ui.ctx.fillStyle = rb.color;
    gameState.ui.ctx.beginPath();
    gameState.ui.ctx.arc(rb.x, rb.y, rb.radius, 0, Math.PI * 2);
    gameState.ui.ctx.fill();
    gameState.ui.ctx.stroke();

    // gun
    const ex = rb.x + Math.cos(rb.angle) * (rb.radius + 5);
    const ey = rb.y + Math.sin(rb.angle) * (rb.radius + 5);

    gameState.ui.ctx.beginPath();
    gameState.ui.ctx.moveTo(rb.x, rb.y);
    gameState.ui.ctx.lineTo(ex, ey);
    gameState.ui.ctx.stroke();

    // projectiles
    gameState.ui.ctx.fillStyle = "black";
    rb.projectiles.forEach(p => {
      gameState.ui.ctx.beginPath();
      gameState.ui.ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
      gameState.ui.ctx.fill();
    });
  });
}
