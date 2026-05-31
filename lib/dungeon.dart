import 'dart:collection';
import 'dart:math';

/// マス（タイル）の種類。今は「壁」「床」「下り階段」の3つだけ。
enum TileType { wall, floor, stairsDown }

/// 長方形の部屋をあらわすデータ。
class Room {
  const Room(this.left, this.top, this.width, this.height);

  final int left;
  final int top;
  final int width;
  final int height;

  int get right => left + width - 1;
  int get bottom => top + height - 1;
  int get centerX => left + width ~/ 2;
  int get centerY => top + height ~/ 2;

  bool contains(int x, int y) =>
      x >= left && x <= right && y >= top && y <= bottom;
}

/// ダンジョン1フロア分の地図データと、その「自動生成」ロジック。
///
/// 生成の流れ（不思議のダンジョン方式）:
/// 1. 全部を壁で埋める
/// 2. 地図を格子状の「区画」に分ける
/// 3. 各区画の中に長方形の部屋をくり抜く
/// 4. 隣りあう区画の部屋どうしを通路でつなぐ（全部つながるようにする）
/// 5. スタート位置と下り階段を別々の部屋に置く
class Dungeon {
  Dungeon({
    required this.width,
    required this.height,
    Random? random,
  }) : _rng = random ?? Random() {
    _generate();
  }

  final int width;
  final int height;
  final Random _rng;

  /// 地図本体。tiles[y][x] で各マスの種類を持つ。
  late List<List<TileType>> tiles;

  /// 各マスがどの部屋に属するか。-1 は「部屋ではない」（通路や壁）。
  late List<List<int>> roomIndexAt;

  /// 生成された部屋の一覧。
  final List<Room> rooms = <Room>[];

  /// プレイヤーの開始位置と、下り階段の位置。
  late Point<int> startPosition;
  late Point<int> stairsPosition;

  bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  /// そのマスを歩けるか（地図の範囲内で、壁でなければ true）。
  bool isWalkable(int x, int y) =>
      inBounds(x, y) && tiles[y][x] != TileType.wall;

  /// そのマスがどの部屋か。-1 なら部屋ではない。
  int roomAt(int x, int y) => inBounds(x, y) ? roomIndexAt[y][x] : -1;

  // ---- 生成 ----------------------------------------------------------

  void _generate() {
    // 1. まず全部「壁」で埋める。
    tiles = List.generate(
      height,
      (_) => List<TileType>.filled(width, TileType.wall),
    );
    roomIndexAt = List.generate(
      height,
      (_) => List<int>.filled(width, -1),
    );
    rooms.clear();

    // 2. 地図を gridCols × gridRows の区画に分ける（2〜3）。
    final gridCols = 2 + _rng.nextInt(2);
    final gridRows = 2 + _rng.nextInt(2);
    final cellW = width ~/ gridCols;
    final cellH = height ~/ gridRows;

    // 3. 各区画に1部屋ずつ作る。
    final sectionRoom =
        List.generate(gridRows, (_) => List<int>.filled(gridCols, -1));

    for (var gy = 0; gy < gridRows; gy++) {
      for (var gx = 0; gx < gridCols; gx++) {
        final left = gx * cellW;
        final top = gy * cellH;
        final right = (gx == gridCols - 1) ? width - 1 : (gx + 1) * cellW - 1;
        final bottom = (gy == gridRows - 1) ? height - 1 : (gy + 1) * cellH - 1;

        // 区画の内側に1マスの余白をとった範囲に部屋を置く
        // （隣の区画の部屋とくっつかないようにするため）。
        final areaLeft = left + 1;
        final areaTop = top + 1;
        final areaW = right - left - 1;
        final areaH = bottom - top - 1;
        if (areaW < 3 || areaH < 3) continue;

        final roomW = 3 + _rng.nextInt(areaW - 2);
        final roomH = 3 + _rng.nextInt(areaH - 2);
        final roomX = areaLeft + _rng.nextInt(areaW - roomW + 1);
        final roomY = areaTop + _rng.nextInt(areaH - roomH + 1);

        final room = Room(roomX, roomY, roomW, roomH);
        final index = rooms.length;
        rooms.add(room);
        sectionRoom[gy][gx] = index;
        _carveRoom(room, index);
      }
    }

    // 4. 区画どうしを通路でつなぐ。
    _connectSections(gridCols, gridRows, sectionRoom);

    // 5. スタートと階段を置く。
    _placeStartAndStairs();
  }

  void _carveRoom(Room room, int index) {
    for (var y = room.top; y <= room.bottom; y++) {
      for (var x = room.left; x <= room.right; x++) {
        tiles[y][x] = TileType.floor;
        roomIndexAt[y][x] = index;
      }
    }
  }

  void _connectSections(
    int gridCols,
    int gridRows,
    List<List<int>> sectionRoom,
  ) {
    final visited =
        List.generate(gridRows, (_) => List<bool>.filled(gridCols, false));
    final connected = <String>{};

    void connect(int ax, int ay, int bx, int by) {
      final ra = sectionRoom[ay][ax];
      final rb = sectionRoom[by][bx];
      if (ra == -1 || rb == -1) return;
      final key = _edgeKey(ax, ay, bx, by);
      if (!connected.add(key)) return;
      _carveCorridor(rooms[ra], rooms[rb]);
    }

    // ランダムな深さ優先探索で全区画を1度ずつ訪れ、通った道をつなぐ。
    // これで「全部の部屋がかならず行き来できる」状態になる。
    void dfs(int x, int y) {
      visited[y][x] = true;
      final dirs = <List<int>>[
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ]..shuffle(_rng);
      for (final d in dirs) {
        final nx = x + d[0];
        final ny = y + d[1];
        if (nx < 0 || ny < 0 || nx >= gridCols || ny >= gridRows) continue;
        if (visited[ny][nx]) continue;
        connect(x, y, nx, ny);
        dfs(nx, ny);
      }
    }

    dfs(0, 0);

    // ときどき余分な通路を足して、ループのある地形にする。
    for (var gy = 0; gy < gridRows; gy++) {
      for (var gx = 0; gx < gridCols; gx++) {
        if (gx + 1 < gridCols && _rng.nextDouble() < 0.25) {
          connect(gx, gy, gx + 1, gy);
        }
        if (gy + 1 < gridRows && _rng.nextDouble() < 0.25) {
          connect(gx, gy, gx, gy + 1);
        }
      }
    }
  }

  /// 向きに関係なく同じ区画ペアを同じ文字列にする（重複接続を防ぐため）。
  String _edgeKey(int ax, int ay, int bx, int by) {
    final a = '$ax,$ay';
    final b = '$bx,$by';
    return a.compareTo(b) < 0 ? '$a-$b' : '$b-$a';
  }

  /// 2つの部屋の中心を、L字の通路でつなぐ。
  void _carveCorridor(Room a, Room b) {
    var x = a.centerX;
    var y = a.centerY;
    final tx = b.centerX;
    final ty = b.centerY;

    void carve(int cx, int cy) {
      if (!inBounds(cx, cy)) return;
      if (tiles[cy][cx] == TileType.wall) {
        tiles[cy][cx] = TileType.floor; // 通路は部屋に属さない（-1のまま）
      }
    }

    if (_rng.nextBool()) {
      while (x != tx) {
        x += tx > x ? 1 : -1;
        carve(x, y);
      }
      while (y != ty) {
        y += ty > y ? 1 : -1;
        carve(x, y);
      }
    } else {
      while (y != ty) {
        y += ty > y ? 1 : -1;
        carve(x, y);
      }
      while (x != tx) {
        x += tx > x ? 1 : -1;
        carve(x, y);
      }
    }
  }

  void _placeStartAndStairs() {
    final startRoom = rooms[_rng.nextInt(rooms.length)];
    startPosition = Point(startRoom.centerX, startRoom.centerY);

    // 階段は、スタートからいちばん遠い部屋に置く（探索しがいを出すため）。
    var stairsRoom = startRoom;
    var bestDist = -1;
    for (final room in rooms) {
      if (room == startRoom) continue;
      final dx = room.centerX - startRoom.centerX;
      final dy = room.centerY - startRoom.centerY;
      final dist = dx * dx + dy * dy;
      if (dist > bestDist) {
        bestDist = dist;
        stairsRoom = room;
      }
    }
    stairsPosition = Point(stairsRoom.centerX, stairsRoom.centerY);
    tiles[stairsPosition.y][stairsPosition.x] = TileType.stairsDown;
  }

  // ---- テスト・確認用のヘルパー --------------------------------------

  /// スタートから歩いて到達できる床マスの数。
  int reachableFloorCount() {
    final seen = List.generate(height, (_) => List<bool>.filled(width, false));
    final queue = Queue<Point<int>>()..add(startPosition);
    seen[startPosition.y][startPosition.x] = true;
    var count = 0;
    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      count++;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = p.x + dx;
          final ny = p.y + dy;
          if (!isWalkable(nx, ny) || seen[ny][nx]) continue;
          // 斜めは壁の角を通り抜けない（移動ルールと合わせる）。
          if (dx != 0 && dy != 0) {
            if (!isWalkable(p.x + dx, p.y) || !isWalkable(p.x, p.y + dy)) {
              continue;
            }
          }
          seen[ny][nx] = true;
          queue.add(Point(nx, ny));
        }
      }
    }
    return count;
  }

  /// 地図全体の床（壁以外）マスの数。
  int totalFloorCount() {
    var count = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (tiles[y][x] != TileType.wall) count++;
      }
    }
    return count;
  }
}
