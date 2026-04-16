# Guia detallada de triangulo_equipo.sma

Este documento explica, paso a paso, como funciona la logica del bot de formacion triangular en bots/triangulo_equipo.sma.
La idea es que puedas entenderlo en dos niveles:
1. Nivel practico: que decision toma en cada momento.
2. Nivel matematico simple: que calculo hace y para que sirve.

## 1) Resumen rapido de la IA

1. Calcula un centro de referencia del mapa usando los goals.
2. Define un triangulo equilatero alrededor de ese centro.
3. Asigna a cada bot un punto objetivo del triangulo.
4. Cada frame, gira hacia su objetivo y camina.
5. Si detecta pared o bloqueo con otro bot, activa maniobras de escape.
6. Si llega a su punto, se queda quieto.

## 2) Funciones y que hace cada una

### wrapPi(angle)
Normaliza un angulo para que quede en el rango [-PI, PI].

En simple:
- Si te pasaste de +180 grados, lo trae para atras.
- Si te pasaste de -180 grados, lo trae para adelante.

Sirve para girar por el camino mas corto.

### atan2(y, x)
Devuelve el angulo del vector (x, y) respecto del eje X.

En simple:
- Le pasas cuanto te falta en X y en Y.
- Te devuelve hacia donde mirar exactamente.
- A diferencia de atan(y/x), atan2 sabe en que cuadrante estas.

Formula de uso en el bot:
$$
\theta = atan2(dy, dx)
$$
donde:
$$
dx = tx - x, \quad dy = ty - y
$$

Por que no alcanza con atan(y/x):
- atan(y/x) pierde informacion de signos cuando x es negativo.
- atan2 corrige eso y entrega el angulo correcto en los 4 cuadrantes.

Casos que maneja esta implementacion:
- Si x es casi 0 y y > 0: devuelve PI/2.
- Si x es casi 0 y y < 0: devuelve -PI/2.
- Si x y y son 0: devuelve 0.
- Si x < 0 ajusta sumando o restando PI segun el signo de y.

### clampf(v, mn, mx)
Recorta un valor para que no salga de un rango.

En simple:
- Si v es menor que mn, devuelve mn.
- Si v es mayor que mx, devuelve mx.
- Si esta en medio, devuelve v.

### rotateTo(absAngle)
Gira al bot hacia un angulo absoluto.

En simple:
- Mira direccion actual.
- Calcula diferencia angular.
- La normaliza con wrapPi para no dar vuelta larga.
- Rota al objetivo por el camino corto.

### isFriendWarrior(item)
Valida si lo detectado por watch es un aliado guerrero.

### getArenaCenter(cx, cy)
Promedia todos los goals de equipos para estimar centro del mapa.

Calculo:
$$
mapCx = \frac{\sum gx}{count}, \quad mapCy = \frac{\sum gy}{count}
$$

Si no hay goals validos, devuelve false.

### getFrontBlockInfo(blockYaw, blockDist, blockId)
Escanea al frente buscando un aliado que bloquee.

Condiciones de bloqueo frontal:
1. Es aliado guerrero.
2. No soy yo.
3. Esta a menos de BLOCK_DIST.
4. Esta casi centrado al frente: abs(yaw) < BLOCK_YAW.

Si encuentra, retorna true y completa:
- blockYaw: hacia que lado esta el bloqueo.
- blockDist: distancia.
- blockId: ID del bot que bloquea.

### isInsideSafe(x, y, mapCx, mapCy, safeHalf)
Revisa si un punto esta dentro de la caja segura centrada en mapCx,mapCy.

### clampPointInsideSafe(x, y, mapCx, mapCy, safeHalf)
Mete un punto dentro de la caja segura usando clamp en X e Y.

### getTriangleRadius()
Calcula radio del triangulo segun cantidad de bots.

Formula:
$$
r = clampf(TRI_BASE_RADIUS + TRI_PER_BOT_RADIUS \cdot (mates - 1), TRI_MIN_RADIUS, TRI_MAX_RADIUS)
$$

### getPairSideSign(idA, idB)
Devuelve +1 o -1 usando paridad de IDs.

Sirve para elegir lado consistente en maniobras entre pares de bots.

### getPassChannelFor(botId)
Canal de radio privado para un bot:
$$
channel = PASS_BASE_CHANNEL + botId
$$

### triangleVertices(cx, cy, r, ...)
Genera vertices de triangulo equilatero centrado en (cx, cy).

Puntos:
1. Vertice superior: (cx, cy + r)
2. Vertice inferior izquierdo: (cx - 0.866r, cy - 0.5r)
3. Vertice inferior derecho: (cx + 0.866r, cy - 0.5r)

Nota:
- 0.866 es aproximacion de sqrt(3)/2.
- 0.5 es 1/2.

### fitTriangleInsideMap(cx, cy, r, mapCx, mapCy, safeHalf)
Ajusta centro y radio para que los 3 vertices queden adentro de la zona segura.

Estrategia:
1. Intenta hasta 18 veces.
2. Si un vertice queda fuera:
- acerca centro al centro del mapa (factor 0.78).
- achica radio (factor 0.90).
3. Aplica limites finales de radio y centro.

### edgePoint(ax, ay, bx, by, t, ox, oy)
Interpolacion lineal en un segmento AB.

Formula:
$$
P(t) = A + t(B - A)
$$
con t entre 0 y 1.

### assignTriangleTarget(cx, cy, r, tx, ty)
Asigna objetivo por bot.

Reglas:
1. Si ID 0: va al centro.
2. Los demas se reparten uniforme por perimetro.

Como reparte:
1. Calcula rank = ID - 1.
2. Calcula u = rank / others.
3. Divide el perimetro en 3 tramos:
- [0, 1/3): lado 0->1
- [1/3, 2/3): lado 1->2
- [2/3, 1): lado 2->0
4. Usa edgePoint para sacar coordenada exacta.

### formationBot()
Es la maquina principal de comportamiento.

Flujo general:
1. Configura centro, radio y objetivo inicial.
2. Inicializa estados de anti-bloqueo.
3. En loop infinito:
- obtiene posicion actual.
- calcula error al objetivo.
- escucha mensajes de paso.
- ejecuta maniobras activas si corresponde.
- si no, navega normal al objetivo.
- detecta bloqueos/paredes/atascos.
- activa estrategia de salida si hace falta.

### fight() y main()
Todas las modalidades llaman a formationBot.

## 3) Variables y constantes: que hace cada una

## 3.1 Constantes de angulo y geometria

| Variable | Valor | Para que sirve |
|---|---:|---|
| PI | 3.1415 | Referencia angular de 180 grados. |
| TWO_PI | 6.2830 | Vuelta completa (360 grados). |

## 3.2 Distancias de llegada y deteccion

| Variable | Valor | Para que sirve |
|---|---:|---|
| ARRIVE_RADIUS | 0.70 | Si el error al objetivo es menor, se considera llegado. |
| WALL_AVOID_DIST | 2.2 | Distancia para empezar a esquivar pared. |
| BLOCK_DIST | 1.9 | Distancia maxima para considerar bloqueo frontal por bot. |
| BLOCK_YAW | 0.65 | Angulo frontal maximo para bloqueo (en radianes). |

## 3.3 Tamano y limites de triangulo

| Variable | Valor | Para que sirve |
|---|---:|---|
| TRI_BASE_RADIUS | 6.0 | Radio base del triangulo. |
| TRI_PER_BOT_RADIUS | 0.55 | Incremento de radio por cada bot extra. |
| TRI_MIN_RADIUS | 5.0 | Radio minimo permitido. |
| TRI_MAX_RADIUS | 14.0 | Radio maximo permitido. |
| MAP_SAFE_HALF | 58.0 | Mitad de caja segura base del mapa. |
| MAP_EDGE_MARGIN | 2.5 | Margen adicional para no pegarse al borde. |
| TRI_BORDER_CLEARANCE | 9.5 | Cuanto recorta la zona segura para el triangulo. |
| TRI_TARGET_MARGIN | 1.2 | Margen adicional al clamping del target. |
| TRI_FIT_MIN_RADIUS | 3.5 | Radio minimo al ajustar triangulo dentro del mapa. |
| CENTER_PULL_TO_ORIGIN | 0.15 | Empuja el centro de goals hacia origen para recentrar. |
| EDGE_NEAR_MARGIN | 1.8 | Umbral para marcar que esta cerca del borde. |

## 3.4 Control de avance y atasco

| Variable | Valor | Para que sirve |
|---|---:|---|
| MOVE_CHECK_DT | 0.35 | Cada cuanto se mide progreso real. |
| MOVE_EPS | 0.07 | Si mueve menos que esto, se considera casi inmovil. |
| STUCK_MAX | 3 | Cantidad de chequeos inmoviles para activar destrabe. |
| BACKOFF_TIME | 0.50 | Duracion de maniobra de backoff suave. |
| BACKOFF_ANGLE | 0.90 | Angulo lateral usado en backoff. |

## 3.5 Escape de pared

| Variable | Valor | Para que sirve |
|---|---:|---|
| WALL_TRAP_DIST | 1.20 | Distancia que se toma como pared peligrosa. |
| WALL_ESCAPE_TIME | 0.75 | Duracion de escape fuerte de pared. |
| WALL_ESCAPE_ANGLE | 1.05 | Angulo usado durante wall escape. |
| WALL_ESCAPE_REARM_DT | 0.30 | Enfriamiento de reactivacion de wall escape. |
| WALL_TRAP_COUNT_MAX | 8 | Umbral de exposicion a pared para cancelar target. |
| WALL_TRAP_COUNT_DT | 0.20 | Paso temporal para subir/bajar contador wallTrapCount. |
| WALL_BREAK_BACK_TIME | 1.20 | Retroceso previo en ruptura fuerte de borde/pared. |
| WALL_BREAK_SIDE_TIME | 0.85 | Fase lateral de wall break. |
| WALL_BREAK_ANGLE | 1.45 | Angulo de salida lateral wall break. |
| WALL_BREAK_REARM_DT | 1.00 | Enfriamiento de wall break. |

## 3.6 Bloqueo entre bots y cesion

| Variable | Valor | Para que sirve |
|---|---:|---|
| BOT_BLOCK_REPEAT_DT | 0.20 | Ventana temporal para acumular repeticiones de bloqueo. |
| BOT_BLOCK_REPEAT_MAX | 4 | Repeticiones para considerar bloqueo severo. |
| BOT_YIELD_TIME | 0.60 | Tiempo base de ceder paso. |
| BOT_YIELD_ANGLE | 1.10 | Angulo lateral para cesion. |
| BOT_YIELD_EXTRA_TIME | 0.30 | Tiempo extra en cesion. |
| BOT_FORCE_BYPASS_TIME | 0.45 | Duracion de bypass forzado del bot con prioridad. |
| BOT_FORCE_BYPASS_ANGLE | 0.85 | Angulo de bypass forzado. |
| DEADLOCK_BACK_TIME | 1.10 | Fase de retroceso en ruptura de deadlock entre bots. |
| DEADLOCK_SIDE_TIME | 0.62 | Fase lateral en ruptura de deadlock. |
| DEADLOCK_SIDE_ANGLE | 1.28 | Angulo lateral en deadlock side. |
| DEADLOCK_COOLDOWN | 0.40 | Cooldown entre rupturas de deadlock. |
| PASS_BASE_CHANNEL | 140 | Base de canal privado para mensajes PASS. |
| WORD_PASS_LEFT | 9101 | Codigo para pedir paso por izquierda. |
| WORD_PASS_RIGHT | 9102 | Codigo para pedir paso por derecha. |
| PASS_RESEND_SAME_TARGET_DT | 0.90 | Evita spam al mismo objetivo. |
| YIELD_BACK_ONLY_TIME | 0.24 | Tiempo corto de retroceso puro al ceder estando quieto. |
| YIELD_SAME_SENDER_COOLDOWN | 0.55 | Ignora spam repetido del mismo emisor. |
| YIELD_GLOBAL_REARM_DT | 0.25 | Enfriamiento global post-yield. |
| BLOCK_SCAN_BACK_TIME | 0.20 | Duracion del lateral corto aleatorio por atasco. |
| BLOCK_SCAN_REARM_DT | 0.60 | Cooldown del lateral corto aleatorio. |
| BACK_PHASE_MIN_GAP | 2.20 | Minimo tiempo entre fases con retroceso fuerte. |

## 3.7 Timming del loop

| Variable | Valor | Para que sirve |
|---|---:|---|
| LOOP_DT | 0.04 | Espera por iteracion del loop principal. |

## 3.8 Variables de estado en runtime (formationBot)

| Variable | Para que sirve |
|---|---|
| mapCx, mapCy | Centro de referencia del mapa. |
| cx, cy | Centro de la formacion triangular. |
| triR | Radio actual del triangulo. |
| tx, ty | Objetivo asignado para este bot. |
| extraMargin | Margen final para objetivo seguro. |
| targetSafeHalf | Caja segura final para clamping de target. |
| lastCheck | Ultima marca temporal de chequeo de progreso. |
| lastX, lastY | Posicion anterior para medir si avanzo. |
| stuckCount | Contador de chequeos con poco o nulo movimiento. |
| backoffUntil | Hasta cuando dura backoff suave. |
| backoffSide | Lado elegido para backoff. |
| wallEscapeUntil | Hasta cuando dura wall escape. |
| wallEscapeRearmUntil | Cooldown para reactivar wall escape. |
| wallEscapeSide | Lado de wall escape. |
| wallTrapCount | Exposicion acumulada a pared cercana. |
| lastWallTrapTick | Ultimo tick para actualizar wallTrapCount. |
| targetCancelled | Si true, cancela navegacion al target y se planta. |
| yieldUntil | Hasta cuando este bot esta cediendo paso. |
| yieldDir | Direccion angular para maniobra de yield. |
| yieldSide | Lado elegido para ceder. |
| yieldHardBack | Si la cesion arranca con retroceso corto. |
| frontBlockId | Ultimo ID detectado bloqueando al frente. |
| frontBlockCount | Cuantas veces seguidas se detecta bloqueo frontal. |
| lastFrontBlockTick | Tick de ultima deteccion frontal. |
| forceBypassUntil | Ventana de bypass forzado del bot prioritario. |
| forceBypassSide | Lado del bypass forzado. |
| deadlockBackUntil | Fin de fase retroceso de deadlock. |
| deadlockSideUntil | Fin de fase lateral de deadlock. |
| deadlockSide | Lado elegido en deadlock. |
| deadlockCooldownUntil | Cooldown para no encadenar deadlock breaks. |
| wallBreakBackUntil | Fin de retroceso de wall break. |
| wallBreakSideUntil | Fin de salida lateral wall break. |
| wallBreakRearmUntil | Cooldown de wall break. |
| wallBreakSide | Lado de wall break. |
| myPassChannel | Canal de radio privado de este bot. |
| lastPassSent | Ultimo momento en que envio PASS. |
| lastPassTarget | Ultimo bot al que pidio paso. |
| lastPassTargetTime | Momento del ultimo PASS a ese target. |
| yieldBackUntil | Fin del mini-retroceso al ceder. |
| yieldGlobalRearmUntil | Cooldown global para re-recibir yields. |
| lastYieldSender | Ultimo bot que le envio PASS. |
| lastYieldRxTime | Tiempo del ultimo PASS recibido. |
| blockScanBackUntil | Fin de lateral corto aleatorio por atasco. |
| blockScanRearmUntil | Cooldown de blockScan. |
| blockScanSide | Lado elegido para blockScan. |
| noBackUntil | Bloqueo temporal para evitar retrocesos encadenados. |

## 3.9 Variables calculadas en cada iteracion

| Variable | Para que sirve |
|---|---|
| now | Tiempo actual. |
| x, y, z | Posicion actual del bot. |
| dx, dy | Diferencia desde posicion actual al objetivo. |
| err | Distancia al objetivo. |
| word, senderId | Mensaje de radio recibido y quien lo envio. |
| blockYaw, blockDist, blockId | Datos del bloqueante frontal detectado. |
| hasFrontBlock | Si hay bloqueo frontal en esta iteracion. |
| severeBlock | Si el bloqueo frontal ya es severo. |
| mx, my, moved | Progreso real medido desde ultimo check. |
| edgeX, edgeY, nearEdge | Cercania al borde de zona segura. |
| stalled | Si casi no avanzo aun queriendo avanzar. |
| wallClose, wallTrapPersistent | Persistencia de riesgo contra pared. |
| touched | Objeto tocado para raise. |

## 4) Que calculos matematicos hace en cada paso (simple)

## Paso A: distancia al objetivo
Cada loop calcula cuanto falta para llegar.

$$
err = \sqrt{(tx-x)^2 + (ty-y)^2}
$$

Si err <= ARRIVE_RADIUS, se queda quieto.

## Paso B: direccion al objetivo
Calcula el vector hacia el target:
$$
dx = tx-x, \quad dy = ty-y
$$

Luego obtiene angulo:
$$
\theta = atan2(dy, dx)
$$

Y rota hacia ese angulo con rotateTo.

## Paso C: evitar giro largo
La diferencia de angulos se normaliza:
$$
\Delta = wrapPi(\theta - dirActual)
$$

Con eso, el bot gira por el camino corto.

## Paso D: detectar estancamiento
Mide cuanto se movio en una ventana temporal:
$$
moved = \sqrt{(x-lastX)^2 + (y-lastY)^2}
$$

Si moved < MOVE_EPS y aun falta llegar, suma stuckCount.

## Paso E: interpolar objetivo sobre lados del triangulo
Para ubicar bots en el perimetro usa interpolacion lineal:
$$
P(t) = A + t(B-A)
$$

Eso calcula un punto exacto entre dos vertices.

## 5) Ejemplo numerico completo

Supongamos:
1. getMates() = 7 bots.
2. Este bot tiene ID = 4.
3. Centro de goals promedio: (10, -6).

### 5.1 Centro ajustado
Con CENTER_PULL_TO_ORIGIN = 0.15:
$$
mapCx = 10 \cdot (1-0.15) = 8.5
$$
$$
mapCy = -6 \cdot (1-0.15) = -5.1
$$

### 5.2 Radio del triangulo
$$
r = 6.0 + 0.55 \cdot (7-1) = 9.3
$$
Como esta entre min y max, queda 9.3.

### 5.3 Vertices
Con (cx,cy)=(8.5,-5.1), r=9.3:
1. V0 = (8.5, 4.2)
2. V1 = (0.4462, -9.75) aprox
3. V2 = (16.5538, -9.75) aprox

### 5.4 Objetivo del bot ID 4
others = mates - 1 = 6
rank = ID - 1 = 3
u = rank/others = 3/6 = 0.5

Como 0.3333 <= u < 0.6666, cae en lado V1 -> V2.
Parametro local:
$$
t = (u - 0.3333) \cdot 3 \approx 0.5001
$$
Es casi mitad de ese lado, asi que target aproximado:
$$
tx \approx 8.5, \quad ty \approx -9.75
$$

### 5.5 Navegacion actual
Si el bot esta en (6.2, -12.0):
$$
dx = 8.5-6.2 = 2.3
$$
$$
dy = -9.75-(-12.0) = 2.25
$$
$$
err = \sqrt{2.3^2 + 2.25^2} \approx 3.22
$$
No llego, debe seguir caminando.

Direccion:
$$
\theta = atan2(2.25, 2.3) \approx 0.775 \text{ rad } \approx 44.4^\circ
$$
Rota hacia ahi y avanza.

### 5.6 Bloqueo frontal
Si detecta otro bot con:
1. blockDist = 0.95
2. abs(blockYaw)=0.10

Entonces severeBlock puede activarse (distancia muy corta).
La IA dispara secuencia anti-deadlock:
1. fase atras (si no esta bloqueado por noBackUntil)
2. fase lateral
3. vuelve a navegar al objetivo

## 6) atan2 vs seno/coseno/tangente en este script

Tu referencia de trigonometria es correcta. Aqui se usa asi:

1. tangente directa:
- tan(a) relaciona cateto opuesto/adyacente.

2. inversa de tangente:
- atan(v) te da angulo desde un valor de tangente.

3. atan2(y, x):
- es como una version robusta de atan(y/x).
- usa y y x por separado.
- sabe el cuadrante correcto.
- evita errores cuando x es 0.

4. seno/coseno:
- en este script no se usan para mover directamente.
- el movimiento usa rotateTo + walk y evita calcular vx/vy con cos/sin.

5. secante/cosecante/cotangente:
- no aparecen en este codigo.
- son utiles en matematica, pero no necesarias para esta IA.

## 7) Maquina de decisiones en palabras simples

Orden de prioridad en cada loop:
1. Si estoy cediendo paso, termino eso primero.
2. Si estoy en una maniobra de escape activa, termino esa maniobra.
3. Si objetivo cancelado, me quedo quieto.
4. Si ya llegue, me quedo quieto.
5. Si no, navego al objetivo.
6. Si hay pared cerca, ajusto direccion.
7. Si hay bot bloqueando, arbitro por ID y aplico PASS/yield/bypass/deadlock break.
8. Si detecto atasco por poco avance, activo lateral aleatorio o backoff.

## 8) Como leer rapido un bug de comportamiento

Si ves que retrocede demasiado:
1. Mira noBackUntil (debe evitar encadenamiento).
2. Revisa si esta entrando repetidamente en deadlockBackUntil o wallBreakBackUntil.
3. Revisa stuckCount y wallTrapCount (si escalan muy rapido, hay sobre-sensibilidad).

Si ves choques de frente entre bots:
1. Revisa frontBlockCount y severeBlock.
2. Verifica canales PASS y cooldown de resend.
3. Ajusta BOT_BLOCK_REPEAT_DT o BOT_BLOCK_REPEAT_MAX.

Si se pega al borde:
1. Revisa targetSafeHalf, EDGE_NEAR_MARGIN, TRI_BORDER_CLEARANCE.
2. Revisa activacion de wallBreak y wallEscape.

## 9) Checklist mental corto

1. Donde quiero ir: (tx,ty).
2. Cuanto me falta: err.
3. Hacia donde miro: atan2(dy,dx).
4. Estoy progresando: moved.
5. Estoy bloqueado por bot: hasFrontBlock.
6. Estoy bloqueado por pared: sight y wallTrapCount.
7. Que maniobra manda ahora: yield, deadlock, wallBreak, wallEscape, blockScan o navegacion normal.
