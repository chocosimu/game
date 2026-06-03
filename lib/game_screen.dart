import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'combat.dart';
import 'dungeon.dart';
import 'monster.dart';
import 'player.dart';

/// ゲーム画面。地図とキャラの描画・入力・ターン管理をまとめて受け持つ。
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.seed});

  /// テストなどで地図を固定したいときに使う種（ふつうは null＝毎回ランダム）。
  final int? seed;

  @override
  State<GameScreen> createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  static const int _mapWidth = 41;
  static const int _mapHeight = 25;

  late Dungeon _dungeon;
  late Player _player;
  final List<Monster> _monsters = <Monster>[];
  late int _playerX;
  late int _playerY;
  int _floor = 1;
  int _turns = 0;

  // 直前のできごと（攻撃・撃破・レベルアップ）を画面に1行で出す。
  String _message = '';
  // 倒れたかどうか（true のあいだは操作できず、やり直し画面を出す）。
  bool _defeated = false;

  // 戦闘の乱数（ダメージのブレ・敵のうろつき）。seed があれば再現できる。
  late final Random _rng;

  // フォグ（霧）。一度でも見たマス／いま見えているマスを覚えておく。
  late List<List<bool>> _discovered;
  late List<List<bool>> _visible;

  final FocusNode _focusNode = FocusNode();
  int _seedOffset = 0;

  @override
  void initState() {
    super.initState();
    _rng = widget.seed != null ? Random(widget.seed! + 9999) : Random();
    _player = Player();
    _generateFloor();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// 新しいフロアの地図を作り、プレイヤーと霧を初期化する。
  void _generateFloor() {
    final random =
        widget.seed != null ? Random(widget.seed! + _seedOffset) : Random();
    _seedOffset++;

    _dungeon = Dungeon(width: _mapWidth, height: _mapHeight, random: random);
    _playerX = _dungeon.startPosition.x;
    _playerY = _dungeon.startPosition.y;
    _discovered =
        List.generate(_mapHeight, (_) => List<bool>.filled(_mapWidth, false));
    _visible =
        List.generate(_mapHeight, (_) => List<bool>.filled(_mapWidth, false));
    _spawnMonsters(random);
    _updateVisibility();
  }

  /// このフロアにモンスターを配置する（今はスライムだけ）。
  /// スタート部屋には置かず、ほかの部屋に2〜4匹ばらまく。
  void _spawnMonsters(Random random) {
    _monsters.clear();
    final startRoomIndex = _dungeon.roomAt(_playerX, _playerY);

    // スタート部屋以外の部屋を候補にする。
    final candidateRooms = <int>[];
    for (var i = 0; i < _dungeon.rooms.length; i++) {
      if (i != startRoomIndex) candidateRooms.add(i);
    }
    candidateRooms.shuffle(random);

    // 2〜4匹（候補の部屋数が少なければその数まで）。
    final count = min(2 + random.nextInt(3), candidateRooms.length);
    for (var i = 0; i < count; i++) {
      final room = _dungeon.rooms[candidateRooms[i]];
      final x = room.left + random.nextInt(room.width);
      final y = room.top + random.nextInt(room.height);
      // プレイヤーや別の敵と重なる位置は避ける。
      if (x == _playerX && y == _playerY) continue;
      if (_monsterAt(x, y) != null) continue;
      _monsters.add(Monster(kind: MonsterKind.slime, x: x, y: y));
    }
  }

  // ----- ここからテスト用の入口（@visibleForTesting）。本編では使わない。 -----

  /// テスト用：プレイヤーの状態を読む。
  @visibleForTesting
  Player get debugPlayer => _player;

  /// テスト用：いまフロアにいる敵の一覧。
  @visibleForTesting
  List<Monster> get debugMonsters => _monsters;

  /// テスト用：倒れたかどうか。
  @visibleForTesting
  bool get debugDefeated => _defeated;

  /// テスト用：プレイヤーから (dx, dy) ずれたマスに敵を1匹置く。
  @visibleForTesting
  Monster debugSpawnMonster(MonsterKind kind, int dx, int dy) {
    final m = Monster(kind: kind, x: _playerX + dx, y: _playerY + dy);
    setState(() => _monsters.add(m));
    return m;
  }

  /// テスト用：プレイヤーの今のHPを差し替える。
  @visibleForTesting
  void debugSetPlayerHp(int hp) => setState(() => _player.hp = hp);

  // ----- テスト用の入口ここまで。 -----

  /// その座標に生きている敵がいれば返す（いなければ null）。
  Monster? _monsterAt(int x, int y) {
    for (final m in _monsters) {
      if (m.isAlive && m.x == x && m.y == y) return m;
    }
    return null;
  }

  void _restart() {
    setState(() {
      _floor = 1;
      _turns = 0;
      _defeated = false;
      _message = '';
      _player = Player();
      _generateFloor();
    });
  }

  /// いまの位置から見えるマスを計算する。
  /// 部屋の中にいるときは部屋全体＋まわり1マス、通路にいるときは周囲8マス。
  void _updateVisibility() {
    for (final row in _visible) {
      row.fillRange(0, row.length, false);
    }

    void reveal(int x, int y) {
      if (!_dungeon.inBounds(x, y)) return;
      _visible[y][x] = true;
      _discovered[y][x] = true;
    }

    final roomIndex = _dungeon.roomAt(_playerX, _playerY);
    if (roomIndex != -1) {
      final room = _dungeon.rooms[roomIndex];
      for (var y = room.top - 1; y <= room.bottom + 1; y++) {
        for (var x = room.left - 1; x <= room.right + 1; x++) {
          reveal(x, y);
        }
      }
    } else {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          reveal(_playerX + dx, _playerY + dy);
        }
      }
    }
  }

  /// (dx, dy) 方向に1マス動こうとする。
  /// ・移動先に敵がいたら「攻撃」になる（その場から動かずに殴る）。
  /// ・壁なら何も起きない（ターンも進まない）。
  void _tryMove(int dx, int dy) {
    if (_defeated) return; // 倒れているあいだは操作できない
    if (dx == 0 && dy == 0) return;
    final nx = _playerX + dx;
    final ny = _playerY + dy;

    // 移動先に敵がいたら、ぶつかって「攻撃」する（移動はしない）。
    final target = _monsterAt(nx, ny);
    if (target != null) {
      setState(() {
        _attackMonster(target);
        _endPlayerTurn(); // 満腹度・自然回復＋敵の行動
      });
      return;
    }

    if (!_dungeon.isWalkable(nx, ny)) return;

    // 斜め移動のときは、壁の角をすり抜けないようにする。
    if (dx != 0 && dy != 0) {
      if (!_dungeon.isWalkable(_playerX + dx, _playerY) ||
          !_dungeon.isWalkable(_playerX, _playerY + dy)) {
        return;
      }
    }

    setState(() {
      _playerX = nx;
      _playerY = ny;
      // 下り階段に乗ったら、次のフロアへ（敵の行動は無し・地形が作り直される）。
      if (_dungeon.tiles[_playerY][_playerX] == TileType.stairsDown) {
        _turns++;
        _player.onStep();
        _floor++;
        _message = 'B${_floor}F へ下りた';
        _generateFloor();
        _checkDefeat();
        return;
      }
      _endPlayerTurn(); // 満腹度・自然回復＋敵の行動
    });
  }

  /// プレイヤーが1回行動したあとの共通処理。
  /// 満腹度・HP自然回復を進め、つづいて敵がいっせいに行動する。
  void _endPlayerTurn() {
    _turns++;
    _player.onStep(); // 満腹度減・空腹ダメージ・HP自然回復（§1.2/§1.4）
    if (_player.isAlive) _enemiesAct();
    _monsters.removeWhere((m) => !m.isAlive); // 倒した敵を片づける
    _updateVisibility();
    _checkDefeat();
  }

  /// プレイヤー → 敵 への攻撃（§1.6 のダメージ式）。
  void _attackMonster(Monster m) {
    final atkPower =
        baseAttackPower(levelAttackFor(_player.level), _player.strength);
    final dmg = rollDamage(baseDamage(atkPower, m.kind.defense), _rng);
    m.hp -= dmg;
    if (m.hp <= 0) {
      m.hp = 0;
      final ups = _player.gainExp(m.kind.exp, _rng);
      _message = '${m.kind.name}を倒した！ EXP +${m.kind.exp}'
          '${ups > 0 ? '／レベルが $ups 上がった！' : ''}';
    } else {
      _message = '${m.kind.name}に $dmg のダメージ';
    }
  }

  /// 敵 → プレイヤー への攻撃（§1.6）。今はプレイヤーの防御力は0（盾なし）。
  void _enemyAttack(Monster m) {
    final dmg = rollDamage(baseDamage(m.kind.attack.toDouble(), 0), _rng);
    _player.hp = (_player.hp - dmg).clamp(0, _player.maxHp);
    _message = '${m.kind.name}の攻撃！ $dmg のダメージ';
  }

  /// このフロアの敵全員に1回ずつ行動させる。
  /// 隣にいれば攻撃／近ければ近づく／遠ければその場でうろつく。
  void _enemiesAct() {
    for (final m in _monsters) {
      if (!m.isAlive) continue;
      if (!_player.isAlive) break; // プレイヤーが倒れたらそこで終了
      final dxToP = _playerX - m.x;
      final dyToP = _playerY - m.y;
      final chebyshev = max(dxToP.abs(), dyToP.abs());

      if (chebyshev == 1) {
        _enemyAttack(m); // 隣接（8方向）なら攻撃
      } else if (_sameRoomAsPlayer(m) || chebyshev <= 3) {
        _moveEnemyToward(m, dxToP.sign, dyToP.sign); // 近いので追いかける
      } else {
        _wanderEnemy(m); // 遠いのでうろつく
      }
    }
  }

  /// 敵 m とプレイヤーが同じ部屋にいるか（通路は -1 なので一致しない）。
  bool _sameRoomAsPlayer(Monster m) {
    final mr = _dungeon.roomAt(m.x, m.y);
    return mr != -1 && mr == _dungeon.roomAt(_playerX, _playerY);
  }

  /// 敵をプレイヤーの方へ1マス寄せる（斜め→縦横の順に通れる方向を探す）。
  void _moveEnemyToward(Monster m, int sx, int sy) {
    final candidates = <(int, int)>[
      if (sx != 0 && sy != 0) (sx, sy),
      if (sx != 0) (sx, 0),
      if (sy != 0) (0, sy),
    ];
    for (final (cdx, cdy) in candidates) {
      if (_canEnemyStep(m, cdx, cdy)) {
        m.x += cdx;
        m.y += cdy;
        return;
      }
    }
  }

  /// 敵をでたらめな方向に1マス動かす（半分はその場でとどまる）。
  void _wanderEnemy(Monster m) {
    if (_rng.nextBool()) return;
    final dirs = <(int, int)>[
      (-1, -1), (0, -1), (1, -1),
      (-1, 0), (1, 0),
      (-1, 1), (0, 1), (1, 1),
    ]..shuffle(_rng);
    for (final (dx, dy) in dirs) {
      if (_canEnemyStep(m, dx, dy)) {
        m.x += dx;
        m.y += dy;
        return;
      }
    }
  }

  /// 敵が (dx, dy) 方向へ1マス動けるか（壁・プレイヤー・別の敵・角抜けを禁止）。
  bool _canEnemyStep(Monster m, int dx, int dy) {
    final nx = m.x + dx;
    final ny = m.y + dy;
    if (!_dungeon.isWalkable(nx, ny)) return false;
    if (nx == _playerX && ny == _playerY) return false; // そこはプレイヤー
    if (_monsterAt(nx, ny) != null) return false; // 別の敵がいる
    if (dx != 0 && dy != 0) {
      if (!_dungeon.isWalkable(m.x + dx, m.y) ||
          !_dungeon.isWalkable(m.x, m.y + dy)) {
        return false;
      }
    }
    return true;
  }

  /// プレイヤーのHPが0なら「倒れた」状態にする。
  void _checkDefeat() {
    if (!_player.isAlive && !_defeated) {
      _defeated = true;
      _message = '力尽きてしまった…';
    }
  }

  /// キーボード入力（PCでの確認用）。矢印・WASD・QEZC に対応。
  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final delta = _deltaForKey(event.logicalKey);
    if (delta != null) _tryMove(delta.$1, delta.$2);
  }

  (int, int)? _deltaForKey(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => (0, -1),
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => (0, 1),
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => (-1, 0),
      LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD => (1, 0),
      LogicalKeyboardKey.keyQ => (-1, -1),
      LogicalKeyboardKey.keyE => (1, -1),
      LogicalKeyboardKey.keyZ => (-1, 1),
      LogicalKeyboardKey.keyC => (1, 1),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKey,
          child: Column(
            children: [
              _buildHud(),
              Expanded(
                child: Stack(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _focusNode.requestFocus,
                      child: CustomPaint(
                        painter: _DungeonPainter(
                          dungeon: _dungeon,
                          playerX: _playerX,
                          playerY: _playerY,
                          discovered: _discovered,
                          visible: _visible,
                          monsters: _monsters,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    if (_defeated) _buildDefeatOverlay(),
                  ],
                ),
              ),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Column(
        children: [
          Row(
            children: [
              _hudChip('B${_floor}F', Icons.stairs_outlined),
              const SizedBox(width: 8),
              _hudChip('ターン $_turns', Icons.history),
              const Spacer(),
              TextButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('最初から'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _hudChip('Lv ${_player.level}', Icons.star_outline),
              const SizedBox(width: 8),
              Expanded(
                child: _statBar(
                  'HP',
                  _player.hp,
                  _player.maxHp,
                  _player.hpRatio,
                  const Color(0xFF66BB6A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBar(
                  '満腹',
                  _player.fullness,
                  _player.maxFullness,
                  _player.fullnessRatio,
                  const Color(0xFFFFCA28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 直前のできごと（攻撃・撃破・レベルアップ）の1行ログ。
          SizedBox(
            height: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 倒れたときに地図の上にかぶせる「やり直し」画面。
  Widget _buildDefeatOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '倒れてしまった…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'B${_floor}F ／ $_turnsターンで力尽きた',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              label: const Text('最初からやり直す'),
            ),
          ],
        ),
      ),
    );
  }

  /// HP・満腹度などの「数値つき横バー」。
  Widget _statBar(String label, int value, int max, double ratio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label $value/$max',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(
                height: 10,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(height: 10, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hudChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 16),
      child: Column(
        children: [
          const Text(
            '矢印キー / WASD・QEZC でも動けます',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _dpadRow(const [(-1, -1, '↖'), (0, -1, '↑'), (1, -1, '↗')]),
          _dpadRow(const [(-1, 0, '←'), (0, 0, ''), (1, 0, '→')]),
          _dpadRow(const [(-1, 1, '↙'), (0, 1, '↓'), (1, 1, '↘')]),
        ],
      ),
    );
  }

  Widget _dpadRow(List<(int, int, String)> items) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (dx, dy, glyph) in items) _dirButton(dx, dy, glyph),
      ],
    );
  }

  Widget _dirButton(int dx, int dy, String glyph) {
    if (glyph.isEmpty) {
      return const SizedBox(width: 64, height: 64);
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('dir_${dx}_$dy'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _tryMove(dx, dy),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Text(
                glyph,
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 地図とキャラを実際に描く部分。カメラは常にプレイヤーを画面中央に置く。
class _DungeonPainter extends CustomPainter {
  _DungeonPainter({
    required this.dungeon,
    required this.playerX,
    required this.playerY,
    required this.discovered,
    required this.visible,
    required this.monsters,
  });

  final Dungeon dungeon;
  final int playerX;
  final int playerY;
  final List<List<bool>> discovered;
  final List<List<bool>> visible;
  final List<Monster> monsters;

  @override
  void paint(Canvas canvas, Size size) {
    // 1マスの大きさを画面に合わせて決める。
    final tile = (min(size.width, size.height) / 13).clamp(16.0, 40.0);

    // カメラ：プレイヤーが画面の真ん中に来るように地図をずらす。
    final camX = playerX * tile + tile / 2 - size.width / 2;
    final camY = playerY * tile + tile / 2 - size.height / 2;

    // 背景（未探索の闇）。
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF05070B),
    );

    // 画面に映る範囲のマスだけ描く。
    final firstX = (camX / tile).floor() - 1;
    final lastX = ((camX + size.width) / tile).ceil() + 1;
    final firstY = (camY / tile).floor() - 1;
    final lastY = ((camY + size.height) / tile).ceil() + 1;

    for (var y = firstY; y <= lastY; y++) {
      for (var x = firstX; x <= lastX; x++) {
        if (x < 0 || y < 0 || x >= dungeon.width || y >= dungeon.height) {
          continue;
        }
        if (!discovered[y][x]) continue; // まだ見たことがない＝闇のまま
        final rect = Rect.fromLTWH(
          x * tile - camX,
          y * tile - camY,
          tile,
          tile,
        );
        _paintTile(canvas, rect, dungeon.tiles[y][x], visible[y][x], tile);
      }
    }

    // モンスター（いま見えているマスにいる敵だけ描く）。
    for (final m in monsters) {
      if (!m.isAlive) continue;
      if (m.x < 0 || m.y < 0 || m.x >= dungeon.width || m.y >= dungeon.height) {
        continue;
      }
      if (!visible[m.y][m.x]) continue;
      final mc = Offset(
        m.x * tile - camX + tile / 2,
        m.y * tile - camY + tile / 2,
      );
      canvas
        ..drawCircle(mc, tile * 0.32, Paint()..color = Color(m.kind.color))
        ..drawCircle(
          mc,
          tile * 0.32,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = tile * 0.06
            ..color = const Color(0xFF134A6B),
        );
    }

    // プレイヤー（画面中央）。
    final center = Offset(
      playerX * tile - camX + tile / 2,
      playerY * tile - camY + tile / 2,
    );
    canvas
      ..drawCircle(center, tile * 0.34, Paint()..color = const Color(0xFFFFD54F))
      ..drawCircle(
        center,
        tile * 0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = tile * 0.06
          ..color = const Color(0xFF7A5B00),
      );
  }

  void _paintTile(
    Canvas canvas,
    Rect rect,
    TileType type,
    bool isVisible,
    double tile,
  ) {
    // いま見えているマスは明るく、前に見ただけのマスは暗め（記憶）に描く。
    final color = switch (type) {
      TileType.wall =>
        isVisible ? const Color(0xFF3A4A63) : const Color(0xFF18202D),
      TileType.floor =>
        isVisible ? const Color(0xFF8294B0) : const Color(0xFF2B3445),
      TileType.stairsDown =>
        isVisible ? const Color(0xFFB98CFF) : const Color(0xFF392C52),
    };

    final inset = rect.deflate(tile * 0.04);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, Radius.circular(tile * 0.14)),
      Paint()..color = color,
    );

    // 下り階段は下向きの三角マークを描く。
    if (type == TileType.stairsDown) {
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final s = tile * 0.22;
      final path = Path()
        ..moveTo(cx - s, cy - s * 0.6)
        ..lineTo(cx + s, cy - s * 0.6)
        ..lineTo(cx, cy + s)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = isVisible ? const Color(0xFF2A1B3D) : const Color(0xFF1B1430),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DungeonPainter oldDelegate) => true;
}
