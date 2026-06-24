//robot.game.helper.functions.js

function robotSelfHit(rb, x, y) {
  const dx = x - rb.x;
  const dy = y - rb.y;
  return Math.sqrt(dx*dx + dy*dy) < 1;
}

function robotOverlap(gameState, x, y, r) {
  const dxp = x - gameState.player.x;
  const dyp = y - gameState.player.y;
  if (Math.sqrt(dxp*dxp + dyp*dyp) < r + gameState.player.radius) return true;

  for (let rb of gameState.robots) {
    if (!rb) continue;
    const dx = x - rb.x;
    const dy = y - rb.y;
    if (Math.sqrt(dx*dx + dy*dy) < r + rb.radius) return true;
  }
  return false;
}

function randomPosition(gameState, radius) {
  let x, y, tries = 0;

  while (tries < 100) {
    x = Math.random() * gameState.ui.canvas.width;
    y = Math.random() * gameState.ui.canvas.height;

    if (!checkCollisions(gameState, x, y) && !robotOverlap(gameState, x, y, radius)) {
      return { x, y };
    }
    tries++;
  }
  return null;
}

function hasLineOfSight(gameState, x1, y1, x2, y2, self) {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const dist = Math.sqrt(dx*dx + dy*dy);

  const steps = Math.floor(dist / 5);
  const stepX = dx / steps;
  const stepY = dy / steps;

  let x = x1;
  let y = y1;

  for (let i = 0; i < steps; i++) {
    x += stepX;
    y += stepY;

    for (let o of gameState.obstacles) {
      if (x > o.x && x < o.x + o.w && y > o.y && y < o.y + o.h) return false;
    }

    for (let rb of gameState.robots) {
      if (!rb) continue;
      if (rb === self) continue;

      const dxr = x - rb.x;
      const dyr = y - rb.y;

      if (Math.sqrt(dxr*dxr + dyr*dyr) < rb.radius) return false;
    }
  }

  return true;
}

function checkCollisions(gameState, nextX, nextY, self = null) {

  const r = self ? self.radius : gameState.player.radius;

  if (
    nextX - r < 0 ||
    nextX + r > gameState.ui.canvas.width ||
    nextY - r < 0 ||
    nextY + r > gameState.ui.canvas.height
  ) return true;

  for (let o of gameState.obstacles) {
    const closestX = Math.max(o.x, Math.min(nextX, o.x + o.w));
    const closestY = Math.max(o.y, Math.min(nextY, o.y + o.h));

    const dx = nextX - closestX;
    const dy = nextY - closestY;

    if (dx * dx + dy * dy < r * r) return true;
  }

  for (let rb of gameState.robots) {
    if (!rb) continue;
    if (rb === self) continue;

    const dx = nextX - rb.x;
    const dy = nextY - rb.y;

    if (Math.sqrt(dx*dx + dy*dy) < r + rb.radius) return true;
  }

  if (self && self !== gameState.player) {
    const dxp = nextX - gameState.player.x;
    const dyp = nextY - gameState.player.y;

    if (Math.sqrt(dxp*dxp + dyp*dyp) < r + gameState.player.radius) return true;
  }

  return false;
}
