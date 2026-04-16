// triangulo_equipo.sma
//
// Formacion triangular fija:
// - ID 0 (jefe) va al centro del mapa.
// - Los demas bots se distribuyen sobre el perimetro de un triangulo
//   segun getMates().

#include "core"
#include "math"
#include "bots"

new const float:PI = 3.1415
new const float:TWO_PI = 6.2830

new const float:ARRIVE_RADIUS = 0.70
new const float:WALL_AVOID_DIST = 2.2
new const float:BLOCK_DIST = 1.9
new const float:BLOCK_YAW = 0.65

new const float:TRI_BASE_RADIUS = 8.0
new const float:TRI_PER_BOT_RADIUS = 0.90
new const float:TRI_MIN_RADIUS = 7.0
new const float:TRI_MAX_RADIUS = 24.0
new const float:MAP_SAFE_HALF = 58.0
new const float:MAP_EDGE_MARGIN = 2.5

new const float:MOVE_CHECK_DT = 0.35
new const float:MOVE_EPS = 0.07
new const STUCK_MAX = 3
new const float:BACKOFF_TIME = 0.50
new const float:BACKOFF_ANGLE = 0.90
new const float:WALL_TRAP_DIST = 1.20
new const float:WALL_ESCAPE_TIME = 0.75
new const float:WALL_ESCAPE_ANGLE = 1.05
new const WALL_TRAP_COUNT_MAX = 8
new const float:WALL_TRAP_COUNT_DT = 0.20

new const float:BOT_BLOCK_REPEAT_DT = 0.20
new const BOT_BLOCK_REPEAT_MAX = 4
new const float:BOT_YIELD_TIME = 0.60
new const float:BOT_YIELD_ANGLE = 1.10
new const float:BOT_YIELD_EXTRA_TIME = 0.30
new const float:BOT_FORCE_BYPASS_TIME = 0.45
new const float:BOT_FORCE_BYPASS_ANGLE = 0.85

new const float:LOOP_DT = 0.04

stock float:wrapPi(float:angle) {
  while(angle > PI) angle -= TWO_PI
  while(angle < -PI) angle += TWO_PI
  return angle
}

stock float:atan2(float:y, float:x) {
  new const float:EPS = 0.00001
  if(abs(x) < EPS) {
    if(y > 0.0) return PI/2.0
    if(y < 0.0) return -PI/2.0
    return 0.0
  }

  new float:a = atan(y/x)
  if(x < 0.0 && y >= 0.0) return a + PI
  if(x < 0.0 && y < 0.0) return a - PI
  return a
}

stock float:clampf(float:v, float:mn, float:mx) {
  if(v < mn) return mn
  if(v > mx) return mx
  return v
}

stock rotateTo(float:absAngle) {
  new float:cur = getDirection()
  rotate(cur + wrapPi(absAngle - cur))
}

stock bool:isFriendWarrior(item) {
  if((item & ITEM_FRIEND) && (item & ITEM_WARRIOR))
    return true
  return false
}

stock bool:getArenaCenter(&float:cx, &float:cy) {
  cx = 0.0
  cy = 0.0

  new count = 0
  for(new t = 0; t < getTeams(); ++t) {
    new float:gx
    new float:gy
    if(getGoalLocation(t, gx, gy)) {
      cx += gx
      cy += gy
      ++count
    }
  }

  if(count <= 0)
    return false

  cx /= float(count)
  cy /= float(count)
  return true
}

stock bool:getFrontBlockInfo(&float:blockYaw, &float:blockDist, &blockId) {
  new item
  new float:dist
  new float:yaw
  new float:pitch
  new id
  new float:minDist = 0.0

  blockYaw = 0.0
  blockDist = 0.0
  blockId = -1

  for(new tries = 0; tries < 8; ++tries) {
    item = ITEM_FRIEND|ITEM_WARRIOR
    dist = minDist
    watch(item, dist, yaw, pitch, id)
    if(item == ITEM_NONE)
      return false

    if(isFriendWarrior(item) && id != getID() && dist < BLOCK_DIST && abs(yaw) < BLOCK_YAW) {
      blockYaw = yaw
      blockDist = dist
      blockId = id
      return true
    }

    minDist = dist + 0.4
  }

  return false
}

stock bool:isInsideSafe(float:x, float:y, float:mapCx, float:mapCy, float:safeHalf) {
  if(abs(x - mapCx) <= safeHalf && abs(y - mapCy) <= safeHalf)
    return true
  return false
}

stock clampPointInsideSafe(&float:x, &float:y, float:mapCx, float:mapCy, float:safeHalf) {
  x = clampf(x, mapCx - safeHalf, mapCx + safeHalf)
  y = clampf(y, mapCy - safeHalf, mapCy + safeHalf)
}

stock float:getTriangleRadius() {
  new mates = getMates()
  if(mates < 1)
    mates = 1

  new float:r = TRI_BASE_RADIUS + TRI_PER_BOT_RADIUS * float(mates - 1)
  return clampf(r, TRI_MIN_RADIUS, TRI_MAX_RADIUS)
}

stock float:getPairSideSign(idA, idB) {
  if(((idA + idB) % 2) == 0)
    return 1.0
  return -1.0
}

stock triangleVertices(float:cx, float:cy,
                       float:r,
                       &float:x0, &float:y0,
                       &float:x1, &float:y1,
                       &float:x2, &float:y2) {
  // Triangulo equilatero centrado en (cx,cy), vertice superior en +Y.
  x0 = cx
  y0 = cy + r

  x1 = cx - 0.8660 * r
  y1 = cy - 0.5000 * r

  x2 = cx + 0.8660 * r
  y2 = cy - 0.5000 * r
}

stock fitTriangleInsideMap(&float:cx, &float:cy, &float:r,
                           float:mapCx, float:mapCy, float:safeHalf) {
  for(new i = 0; i < 18; ++i) {
    new float:x0
    new float:y0
    new float:x1
    new float:y1
    new float:x2
    new float:y2
    triangleVertices(cx, cy, r, x0, y0, x1, y1, x2, y2)

    if(isInsideSafe(x0, y0, mapCx, mapCy, safeHalf) &&
       isInsideSafe(x1, y1, mapCx, mapCy, safeHalf) &&
       isInsideSafe(x2, y2, mapCx, mapCy, safeHalf))
      return

    // Si hay vertices fuera, acercar centro al centro del mapa y reducir radio.
    cx = mapCx + (cx - mapCx) * 0.78
    cy = mapCy + (cy - mapCy) * 0.78
    r *= 0.90
    r = clampf(r, TRI_MIN_RADIUS, TRI_MAX_RADIUS)
  }
}

stock edgePoint(float:ax, float:ay, float:bx, float:by, float:t, &float:ox, &float:oy) {
  ox = ax + (bx - ax) * t
  oy = ay + (by - ay) * t
}

stock assignTriangleTarget(float:cx, float:cy, float:r, &float:tx, &float:ty) {
  // Jefe al centro.
  if(getID() == 0) {
    tx = cx
    ty = cy
    return
  }

  new mates = getMates()
  new others = mates - 1
  if(others <= 0) {
    tx = cx
    ty = cy
    return
  }

  new rank = getID() - 1
  if(rank < 0)
    rank = 0
  if(rank >= others)
    rank = rank % others

  new float:x0
  new float:y0
  new float:x1
  new float:y1
  new float:x2
  new float:y2
  triangleVertices(cx, cy, r, x0, y0, x1, y1, x2, y2)

  // Distribucion uniforme a lo largo del perimetro.
  new float:u = float(rank) / float(others)
  if(u < 0.3333) {
    edgePoint(x0, y0, x1, y1, u * 3.0, tx, ty)
  } else if(u < 0.6666) {
    edgePoint(x1, y1, x2, y2, (u - 0.3333) * 3.0, tx, ty)
  } else {
    edgePoint(x2, y2, x0, y0, (u - 0.6666) * 3.0, tx, ty)
  }
}

formationBot() {
  // Centro real del mapa usado como referencia de limites.
  new float:mapCx
  new float:mapCy
  if(!getArenaCenter(mapCx, mapCy)) {
    mapCx = 0.0
    mapCy = 0.0
  }

  // Centro de formacion (puede ajustarse hacia adentro).
  new float:cx = mapCx
  new float:cy = mapCy

  // Radio inicial y ajuste para garantizar vertices dentro del mapa.
  new float:triR = getTriangleRadius()
  new float:safeHalf = MAP_SAFE_HALF
  fitTriangleInsideMap(cx, cy, triR, mapCx, mapCy, safeHalf)

  new float:tx
  new float:ty
  assignTriangleTarget(cx, cy, triR, tx, ty)
  new float:safeInner = safeHalf - MAP_EDGE_MARGIN
  new bool:targetWasOutside = !isInsideSafe(tx, ty, mapCx, mapCy, safeInner)
  clampPointInsideSafe(tx, ty, mapCx, mapCy, safeHalf - MAP_EDGE_MARGIN)

  new float:lastCheck = -1000.0
  new float:lastX = cx
  new float:lastY = cy
  new stuckCount = 0
  new float:backoffUntil = -1000.0
  new float:backoffSide = 1.0
  new float:wallEscapeUntil = -1000.0
  new float:wallEscapeSide = 1.0
  new bool:arrivedPrinted = false
  new wallTrapCount = 0
  new float:lastWallTrapTick = -1000.0
  new bool:targetCancelled = false
  new float:yieldUntil = -1000.0
  new float:yieldDir = 0.0
  new float:yieldSide = 1.0
  new bool:yieldHardBack = false
  new frontBlockId = -1
  new frontBlockCount = 0
  new float:lastFrontBlockTick = -1000.0
  new float:forceBypassUntil = -1000.0
  new float:forceBypassSide = 1.0

  walk()
  printf("TRI-ID-%d OBJ(%d,%d) C(%d,%d) R-%d^n",
         getID(),
         floatround(tx), floatround(ty),
         floatround(cx), floatround(cy),
         floatround(triR))

  for(;;) {
    new float:now = getTime()

    new float:x
    new float:y
    new float:z
    getLocation(x, y, z)

    new float:dx = tx - x
    new float:dy = ty - y
    new float:err = sqrt(dx*dx + dy*dy)

    // Fallback de seguridad: si objetivo provoca choque de pared persistente, cancelar.
    if(targetCancelled) {
      if(isWalking() || isRunning() || isWalkingbk() || isWalkingcr())
        stand()

      wait(LOOP_DT)
      continue
    }

    if(err <= ARRIVE_RADIUS) {
      if(!arrivedPrinted) {
        if(getID() == 0)
          printf("TRI-ID-%d JEFE-CENTRO-OK^n", getID())
        else
          printf("TRI-ID-%d POSICION-OK^n", getID())
        arrivedPrinted = true
      }

      if(isWalking() || isRunning() || isWalkingbk() || isWalkingcr())
        stand()

      wait(LOOP_DT)
      continue
    }

    // Si aun no llego, seguir navegando.
    arrivedPrinted = false

    // Escape fuerte de pared para no quedar empujando infinito.
    if(now < wallEscapeUntil) {
      rotateTo(getDirection() + wallEscapeSide * WALL_ESCAPE_ANGLE)
      if(isStanding() || isWalkingbk() || isWalkingcr())
        walk()

      if(sight() < WALL_TRAP_DIST)
        wallEscapeSide = -wallEscapeSide

      wait(LOOP_DT)
      continue
    }

    if(now < backoffUntil) {
      rotateTo(getDirection() + backoffSide * BACKOFF_ANGLE)
      if(sight() < WALL_AVOID_DIST)
        rotateTo(getDirection() - backoffSide * PI/2.5)

      if(isStanding() || isWalkingbk() || isWalkingcr())
        walk()

      wait(LOOP_DT)
      continue
    }

    // Si este bot esta cediendo el paso, ejecutar maniobra temporal.
    if(now < yieldUntil) {
      rotateTo(yieldDir)

      if(sight() < WALL_AVOID_DIST)
        rotateTo(getDirection() - yieldSide * PI/2.8)

      if(yieldHardBack) {
        if(isStanding() || isWalking() || isRunning() || isWalkingcr())
          walkbk()
      } else {
        if(isStanding() || isWalkingbk() || isWalkingcr())
          walk()
      }

      wait(LOOP_DT)
      continue
    }

    // Si tengo prioridad y aun asi sigo bloqueado, forzar bypass corto.
    if(now < forceBypassUntil) {
      rotateTo(getDirection() + forceBypassSide * BOT_FORCE_BYPASS_ANGLE)

      if(sight() < WALL_AVOID_DIST)
        rotateTo(getDirection() - forceBypassSide * PI/2.6)

      if(isStanding() || isWalkingbk() || isWalkingcr())
        walk()

      wait(LOOP_DT)
      continue
    }

    // Navegacion principal al objetivo.
    rotateTo(atan2(dy, dx))

    // Evitar pared.
    if(sight() < WALL_AVOID_DIST)
      rotateTo(getDirection() + (random(2) == 0 ? PI/4.0 : -PI/4.0))

    if(sight() < WALL_TRAP_DIST) {
      wallEscapeUntil = now + WALL_ESCAPE_TIME
      wallEscapeSide = (random(2) == 0 ? 1.0 : -1.0)

      if(now - lastWallTrapTick >= WALL_TRAP_COUNT_DT) {
        ++wallTrapCount
        lastWallTrapTick = now
      }
    } else if(now - lastWallTrapTick >= WALL_TRAP_COUNT_DT && wallTrapCount > 0) {
      --wallTrapCount
      lastWallTrapTick = now
    }

    if(err > ARRIVE_RADIUS && wallTrapCount >= WALL_TRAP_COUNT_MAX) {
      targetCancelled = true
      tx = x
      ty = y
      if(isWalking() || isRunning() || isWalkingbk() || isWalkingcr())
        stand()

      if(targetWasOutside)
        printf("TRI-ID-%d OBJ-CANCELADO-PARED (OBJ-FUERA)^n", getID())
      else
        printf("TRI-ID-%d OBJ-CANCELADO-PARED (TRAMPA-BORDE)^n", getID())

      wait(LOOP_DT)
      continue
    }

    // Arbitraje anti-bloqueo entre bots: menor ID mantiene prioridad.
    new float:blockYaw
    new float:blockDist
    new blockId
    new bool:hasFrontBlock = getFrontBlockInfo(blockYaw, blockDist, blockId)

    if(hasFrontBlock) {
      if(blockId == frontBlockId && now - lastFrontBlockTick <= BOT_BLOCK_REPEAT_DT)
        ++frontBlockCount
      else
        frontBlockCount = 1

      frontBlockId = blockId
      lastFrontBlockTick = now

      new severeBlock = (frontBlockCount >= BOT_BLOCK_REPEAT_MAX || blockDist < 1.05)

      // El ID mas alto cede para romper deadlocks de frente.
      if(getID() > blockId) {
        yieldSide = getPairSideSign(getID(), blockId)
        yieldDir = getDirection() + yieldSide * BOT_YIELD_ANGLE
        yieldHardBack = (severeBlock != 0)
        yieldUntil = now + BOT_YIELD_TIME
        if(yieldHardBack)
          yieldUntil += BOT_YIELD_EXTRA_TIME

        wait(LOOP_DT)
        continue
      }

      // El ID con prioridad intenta paso lateral; si persiste, bypass temporal.
      if(severeBlock) {
        forceBypassSide = (blockYaw > 0.0 ? -1.0 : 1.0)
        forceBypassUntil = now + BOT_FORCE_BYPASS_TIME
        wait(LOOP_DT)
        continue
      }

      rotateTo(getDirection() + (blockYaw > 0.0 ? -PI/6.0 : PI/6.0))
    } else if(now - lastFrontBlockTick >= BOT_BLOCK_REPEAT_DT && frontBlockCount > 0) {
      --frontBlockCount
      lastFrontBlockTick = now
    }

    if(isStanding() || isWalkingbk() || isWalkingcr())
      walk()

    // Deteccion de atasco local.
    if(now - lastCheck >= MOVE_CHECK_DT) {
      new float:mx = x - lastX
      new float:my = y - lastY
      new float:moved = sqrt(mx*mx + my*my)

      if(err > ARRIVE_RADIUS && moved < MOVE_EPS)
        ++stuckCount
      else
        stuckCount = 0

      lastX = x
      lastY = y
      lastCheck = now
    }

    if(stuckCount >= STUCK_MAX) {
      backoffUntil = now + BACKOFF_TIME
      backoffSide = (random(2) == 0 ? 1.0 : -1.0)
      stuckCount = 0
    }

    new touched = getTouched()
    if(touched)
      raise(touched)

    wait(LOOP_DT)
  }
}

fight() {
  formationBot()
}

main() {
  switch(getPlay()) {
    case PLAY_FIGHT: fight()
    case PLAY_SOCCER: fight()
    case PLAY_RACE: fight()
  }
}
