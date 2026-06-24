// robot.game.ui.dart
// The whole screen: sidebar controls, the canvas with mouse + keyboard input,
// the resize-warning modal, and the Ticker that drives the frame loop. This
// replaces the HTML sidebar, the DOM event listeners in robot.game.html, and
// robot.game.modal.functions.js.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // kPrimaryButton / kSecondaryButton
import 'package:flutter/scheduler.dart'; // Ticker
import 'package:flutter/services.dart';

import 'robot.game.state.dart';
import 'robot.game.storage.dart';
import 'robot.game.engine.dart';
import 'robot.game.player.dart';
import 'robot.game.robot.dart';
import 'robot.game.painter.dart';

const Color _kSidebarBg = Color(0xFFEAF2FF);
const Color _kActive = Color(0xFF4A7CFF);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final GameState gs = GameState();
  late final Ticker _ticker;
  final FocusNode _gameFocus = FocusNode();

  // Sidebar text fields.
  late final TextEditingController _wCtrl;
  late final TextEditingController _hCtrl;
  late final TextEditingController _s1Ctrl;
  late final TextEditingController _s2Ctrl;
  final List<FocusNode> _fieldFocus = List.generate(4, (_) => FocusNode());

  // Collapsible sections (the original persisted these; kept in-memory here).
  bool _playAreaOpen = true;
  bool _obstacleOpen = true;
  bool _helpOpen = false;

  // Resize-drag state (was robot.game.modal.functions.js).
  bool _resizeAccepted = false; // resets every launch, like the original
  bool _isResizing = false;
  String _resizeType = 'both';
  MouseCursor _canvasCursor = SystemMouseCursors.basic;

  @override
  void initState() {
    super.initState();

    final hasSave = Storage.load(gs);
    if (!hasSave) {
      resetCanvas(gs);
    }

    _wCtrl = TextEditingController(text: gs.canvasWidth.toInt().toString());
    _hCtrl = TextEditingController(text: gs.canvasHeight.toInt().toString());
    _s1Ctrl = TextEditingController(text: gs.side1.toString());
    _s2Ctrl = TextEditingController(text: gs.side2.toString());

    _ticker = createTicker((_) {
      tick(gs);
      setState(() {}); // repaint the canvas + refresh control states
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _gameFocus.dispose();
    _wCtrl.dispose();
    _hCtrl.dispose();
    _s1Ctrl.dispose();
    _s2Ctrl.dispose();
    for (final f in _fieldFocus) {
      f.dispose();
    }
    super.dispose();
  }

  void _syncDimControllers() {
    _wCtrl.text = gs.canvasWidth.toInt().toString();
    _hCtrl.text = gs.canvasHeight.toInt().toString();
  }

  bool get _anyFieldFocused => _fieldFocus.any((f) => f.hasFocus);

  /* =========================
     KEYBOARD
  ========================= */

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (_anyFieldFocused) return KeyEventResult.ignored;

    final key = e.logicalKey;

    if (e is KeyDownEvent || e is KeyRepeatEvent) {
      // Obstacle delete / selection cancel (mirrors the original keydown head).
      if (gs.selectedObstacleIndex != null) {
        if (key == LogicalKeyboardKey.delete ||
            key == LogicalKeyboardKey.backspace) {
          gs.obstacles.removeAt(gs.selectedObstacleIndex!);
          gs.selectedObstacleIndex = null;
          Storage.save(gs);
          return KeyEventResult.handled;
        } else {
          gs.selectedObstacleIndex = null;
        }
      }

      if (key == LogicalKeyboardKey.keyM) {
        _setManual();
      } else if (key == LogicalKeyboardKey.keyR) {
        _setRandom();
      } else if (key == LogicalKeyboardKey.keyC) {
        doCloak(gs);
      } else if (key == LogicalKeyboardKey.keyA) {
        _keyAppearTeleport();
      }

      // Cloak above may have hidden the player.
      if (!gs.player.visible) return KeyEventResult.handled;

      if (key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight) {
        gs.player.isStrafing = true;
      }
      if (key == LogicalKeyboardKey.arrowLeft) gs.player.rotatingCCW = true;
      if (key == LogicalKeyboardKey.arrowRight) gs.player.rotatingCW = true;
      if (key == LogicalKeyboardKey.arrowUp) gs.player.movingForward = true;
      if (key == LogicalKeyboardKey.arrowDown) gs.player.movingBackward = true;

      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyF) {
        gs.player.wantFire = true;
      }
      return KeyEventResult.handled;
    }

    if (e is KeyUpEvent) {
      if (key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight) {
        gs.player.isStrafing = false;
      }
      if (key == LogicalKeyboardKey.arrowLeft) gs.player.rotatingCCW = false;
      if (key == LogicalKeyboardKey.arrowRight) gs.player.rotatingCW = false;
      if (key == LogicalKeyboardKey.arrowUp) gs.player.movingForward = false;
      if (key == LogicalKeyboardKey.arrowDown) gs.player.movingBackward = false;
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _keyAppearTeleport() {
    // The 'a' key in the original force-revives + teleports to a random spot.
    gs.player.isDead = false;
    gs.player.visible = true;
    gs.player.numBeenHit = 0;
    gs.player.damageLevel = 0;
    gs.player.isHit = false;
    gs.placingPlayer = false;

    final pos = randomPosition(gs, gs.player.radius);
    if (pos != null) {
      gs.player.x = pos.x;
      gs.player.y = pos.y;
    } else {
      gs.player.x = gs.canvasWidth / 2;
      gs.player.y = gs.canvasHeight / 2;
    }
    Storage.save(gs);
  }

  /* =========================
     MOUSE (canvas)
  ========================= */

  void _onPointerDown(PointerDownEvent e) {
    _gameFocus.requestFocus();
    final x = e.localPosition.dx;
    final y = e.localPosition.dy;
    const margin = 15.0;

    final nearEdge =
        x > gs.canvasWidth - margin || y > gs.canvasHeight - margin;

    if (nearEdge) {
      _beginResize(x, y);
      return;
    }

    // Hit-test existing obstacles.
    int? clickedIndex;
    for (var i = 0; i < gs.obstacles.length; i++) {
      final o = gs.obstacles[i];
      if (x >= o.x && x <= o.x + o.w && y >= o.y && y <= o.y + o.h) {
        clickedIndex = i;
        break;
      }
    }

    if (clickedIndex != null) {
      gs.selectedObstacleIndex = clickedIndex;
      if (gs.arrowActive) {
        gs.draggingObstacle = gs.obstacles[clickedIndex];
        gs.dragOffsetX = x - gs.draggingObstacle!.x;
        gs.dragOffsetY = y - gs.draggingObstacle!.y;
      }
      return;
    } else {
      gs.selectedObstacleIndex = null;
    }

    // Place the player.
    if (gs.placingPlayer) {
      gs.player.x = x;
      gs.player.y = y;
      gs.player.isDead = false;
      gs.player.numBeenHit = 0;
      gs.player.damageLevel = 0;
      gs.player.visible = true;
      gs.placingPlayer = false;
      return;
    }

    // Start an obstacle preview.
    if (gs.arrowActive) {
      final s1 = gs.side1;
      final s2 = gs.side2;
      final longSide = max(s1, s2).toDouble();
      final shortSide = min(s1, s2).toDouble();

      double w, h;
      if (gs.obstacleOrientation == 'horz') {
        w = longSide;
        h = shortSide;
      } else {
        w = shortSide;
        h = longSide;
      }

      gs.previewObstacle =
          Obstacle(x: x - w / 2, y: y - h / 2, w: w, h: h);
      return;
    }

    // Otherwise rotate: left button CCW, right button CW.
    if ((e.buttons & kPrimaryButton) != 0) gs.player.rotatingCCW = true;
    if ((e.buttons & kSecondaryButton) != 0) gs.player.rotatingCW = true;
  }

  void _onPointerMove(PointerMoveEvent e) {
    final x = e.localPosition.dx;
    final y = e.localPosition.dy;

    if (_isResizing) {
      _performResize(x, y);
      return;
    }

    if (gs.draggingObstacle != null) {
      gs.draggingObstacle!.x = x - gs.dragOffsetX;
      gs.draggingObstacle!.y = y - gs.dragOffsetY;
    } else if (gs.previewObstacle != null) {
      gs.previewObstacle!.x = x - gs.previewObstacle!.w / 2;
      gs.previewObstacle!.y = y - gs.previewObstacle!.h / 2;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_isResizing) {
      _isResizing = false;
    }

    if (gs.draggingObstacle != null) {
      gs.draggingObstacle = null;
      Storage.save(gs);
    }

    if (gs.previewObstacle != null) {
      gs.obstacles.add(gs.previewObstacle!);
      gs.previewObstacle = null;
      Storage.save(gs);
    }

    // Release stops rotation (Flutter doesn't report which button released).
    gs.player.rotatingCCW = false;
    gs.player.rotatingCW = false;
  }

  void _onHover(PointerHoverEvent e) {
    if (_isResizing) return;
    final x = e.localPosition.dx;
    final y = e.localPosition.dy;
    const m = 15.0;
    final atR = x > gs.canvasWidth - m;
    final atB = y > gs.canvasHeight - m;

    MouseCursor c;
    if (atR && atB) {
      c = SystemMouseCursors.resizeUpLeftDownRight;
    } else if (atR) {
      c = SystemMouseCursors.resizeLeftRight;
    } else if (atB) {
      c = SystemMouseCursors.resizeUpDown;
    } else {
      c = SystemMouseCursors.basic;
    }
    if (c != _canvasCursor) {
      setState(() => _canvasCursor = c);
    }
  }

  /* =========================
     RESIZE (modal + drag)
  ========================= */

  void _beginResize(double x, double y) {
    const margin = 15.0;
    final atR = x > gs.canvasWidth - margin;
    final atB = y > gs.canvasHeight - margin;

    if (!_resizeAccepted) {
      _showResizeWarning();
      return;
    }

    _isResizing = true;
    if (atR && atB) {
      _resizeType = 'both';
    } else if (atR) {
      _resizeType = 'width';
    } else {
      _resizeType = 'height';
    }
  }

  void _performResize(double x, double y) {
    if (_resizeType == 'width' || _resizeType == 'both') {
      gs.canvasWidth = max(50, x.round()).toDouble();
    }
    if (_resizeType == 'height' || _resizeType == 'both') {
      gs.canvasHeight = max(50, y.round()).toDouble();
    }
    // The original dispatched an 'input' event, which ran resetCanvas().
    resetCanvas(gs);
    _syncDimControllers();
  }

  void _showResizeWarning() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Warning'),
        content: const Text(
            'Manually resizing the canvas will completely reset and clear the '
            'current game. Do you want to proceed?'),
        actions: [
          TextButton(
            onPressed: () {
              _resizeAccepted = true; // click again to start the drag
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /* =========================
     SIDEBAR ACTIONS
  ========================= */

  void _setManual() {
    gs.player.movementMode = 'manual';
    gs.player.fireMode = false;
    gs.player.evadeMode = false;
    Storage.save(gs);
  }

  void _setRandom() {
    gs.player.movementMode = 'random';
    Storage.save(gs);
  }

  void _toggleFire() {
    gs.player.fireMode = !gs.player.fireMode;
    if (gs.player.fireMode) {
      gs.player.evadeMode = false;
      gs.player.huntMode = false;
    }
    Storage.save(gs);
  }

  void _toggleEvade() {
    gs.player.evadeMode = !gs.player.evadeMode;
    if (gs.player.evadeMode) {
      gs.player.fireMode = false;
      gs.player.huntMode = false;
    }
    Storage.save(gs);
  }

  void _toggleHunt() {
    gs.player.huntMode = !gs.player.huntMode;
    if (gs.player.huntMode) {
      gs.player.fireMode = false;
      gs.player.evadeMode = false;
    }
    Storage.save(gs);
  }

  void _reload() {
    gs.player.ammo = 100;
    Storage.save(gs);
  }

  void _toggleRobot(int id) {
    if (gs.robots[id] != null) {
      gs.robots[id] = null;
    } else {
      gs.robots[id] = createRobot(gs);
    }
    Storage.save(gs);
  }

  void _applyWidth(String v) {
    final n = int.tryParse(v);
    if (n != null && n >= 50) {
      gs.canvasWidth = n.toDouble();
      resetCanvas(gs);
    }
  }

  void _applyHeight(String v) {
    final n = int.tryParse(v);
    if (n != null && n >= 50) {
      gs.canvasHeight = n.toDouble();
      resetCanvas(gs);
    }
  }

  /* =========================
     BUILD
  ========================= */

  @override
  Widget build(BuildContext context) {
    final isRandom = gs.player.movementMode == 'random';
    final outOfAmmo = gs.player.ammo <= 0;

    return Focus(
      focusNode: _gameFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sidebar(isRandom, outOfAmmo),
            Expanded(
              child: Container(
                color: const Color(0xFFF4F7FB),
                child: Center(child: _canvasArea()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _canvasArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCCCCCC)),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: MouseRegion(
        cursor: _canvasCursor,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerHover: _onHover,
          child: CustomPaint(
            size: Size(gs.canvasWidth, gs.canvasHeight),
            painter: GamePainter(gs),
          ),
        ),
      ),
    );
  }

  Widget _sidebar(bool isRandom, bool outOfAmmo) {
    return Container(
      width: 220,
      color: _kSidebarBg,
      padding: const EdgeInsets.all(15),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _collapsible('Play Area', _playAreaOpen,
                () => setState(() => _playAreaOpen = !_playAreaOpen), [
              _numField('Width', _wCtrl, _fieldFocus[0], _applyWidth),
              _numField('Height', _hCtrl, _fieldFocus[1], _applyHeight),
            ]),
            const _Separator(),
            _collapsible('Obstacle', _obstacleOpen,
                () => setState(() => _obstacleOpen = !_obstacleOpen), [
              _numField('Side 1', _s1Ctrl, _fieldFocus[2], (v) {
                final n = int.tryParse(v);
                if (n != null) {
                  gs.side1 = n;
                  Storage.save(gs);
                }
              }),
              _numField('Side 2', _s2Ctrl, _fieldFocus[3], (v) {
                final n = int.tryParse(v);
                if (n != null) {
                  gs.side2 = n;
                  Storage.save(gs);
                }
              }),
              _row([
                _btn('Horz',
                    active: gs.obstacleOrientation == 'horz', onTap: () {
                  gs.obstacleOrientation = 'horz';
                  Storage.save(gs);
                }),
                _btn('Vert',
                    active: gs.obstacleOrientation == 'vert', onTap: () {
                  gs.obstacleOrientation = 'vert';
                  Storage.save(gs);
                }),
                _btn('➤', active: gs.arrowActive, onTap: () {
                  gs.arrowActive = !gs.arrowActive;
                  Storage.save(gs);
                }),
              ]),
            ]),
            const _Separator(),
            const _Title('Player'),
            _row([
              _btn('Manual',
                  active: gs.player.movementMode == 'manual',
                  onTap: _setManual),
              _btn('Random', active: isRandom, onTap: _setRandom),
            ]),
            _row([
              _btn('Cloak', active: !gs.player.visible, onTap: () => doCloak(gs)),
              _btn('Appear', active: gs.placingPlayer, onTap: () => doAppear(gs)),
            ]),
            _row([
              _btn('Fire',
                  active: gs.player.fireMode,
                  red: outOfAmmo,
                  onTap: isRandom ? _toggleFire : null),
              _btn('Evade',
                  active: gs.player.evadeMode,
                  onTap: isRandom ? _toggleEvade : null),
            ]),
            _row([
              _btn('Reload',
                  onTap: (isRandom && outOfAmmo) ? _reload : null),
              _btn('Hunt',
                  active: gs.player.huntMode,
                  onTap: isRandom ? _toggleHunt : null),
            ]),
            const _Separator(),
            const _Title('Robots'),
            _row([
              for (var i = 0; i < 5; i++)
                _btn('R',
                    active: gs.robots[i] != null,
                    onTap: () => _toggleRobot(i)),
            ]),
            _row([
              _btn('Fire', active: gs.robotFireMode, onTap: () {
                gs.robotFireMode = !gs.robotFireMode;
                Storage.save(gs);
              }),
            ]),
            const _Separator(),
            _collapsible('Help / Controls', _helpOpen,
                () => setState(() => _helpOpen = !_helpOpen), const [
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'KEYBOARD\n'
                  '• Arrows: Move / Turn\n'
                  '• Shift + Arrows: Slide\n'
                  '• Space / F: Fire\n'
                  '• Del / Backspace: Remove obstacle\n'
                  '• C: Cloak   • A: Appear\n'
                  '• M: Manual   • R: Random\n\n'
                  'MOUSE\n'
                  '• Left Click: Rotate CCW\n'
                  '• Right Click: Rotate CW\n'
                  '• Canvas Click: Place Player (Appear active)\n'
                  '• Drag right/bottom edge: Resize (resets game)\n\n'
                  'TIPS\n'
                  '• Red flash = damage / bump\n'
                  '• 5 hits = destroyed\n'
                  '• Ammo refills only in Random via Reload',
                  style: TextStyle(fontSize: 12, height: 1.3, color: Color(0xFF444444)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /* ---- small UI helpers ---- */

  Widget _collapsible(
      String title, bool open, VoidCallback onToggle, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(open ? '▼' : '▶', style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
        if (open) ...children,
      ],
    );
  }

  Widget _numField(String label, TextEditingController c, FocusNode f,
      ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            focusNode: f,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _row(List<Widget> kids) {
    final out = <Widget>[];
    for (var i = 0; i < kids.length; i++) {
      out.add(Expanded(child: kids[i]));
      if (i < kids.length - 1) out.add(const SizedBox(width: 5));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: out),
    );
  }

  Widget _btn(String label,
      {bool active = false, bool red = false, VoidCallback? onTap}) {
    final disabled = onTap == null;
    Color bg;
    Color fg;
    if (disabled) {
      bg = const Color(0xFFCCCCCC);
      fg = Colors.black;
    } else if (active) {
      bg = _kActive;
      fg = Colors.white;
    } else if (red) {
      bg = Colors.red;
      fg = Colors.white;
    } else {
      bg = const Color(0xFFE0E0E0);
      fg = Colors.black;
    }

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: fg, fontSize: 13)),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      );
}

class _Separator extends StatelessWidget {
  const _Separator();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1, color: Color(0xFFCDD8EE)),
      );
}
