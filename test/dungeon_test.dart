// ダンジョン自動生成の正しさを確かめるテスト。
//
// いちばん大事なのは「生成された地図のすべての床に、スタートから
// 歩いてたどり着けること」（行き止まりで孤立した部屋がないこと）。

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:game/dungeon.dart';

void main() {
  Dungeon make(int seed) =>
      Dungeon(width: 41, height: 25, random: Random(seed));

  test('すべての床マスにスタートからたどり着ける（地図がつながっている）', () {
    for (var seed = 0; seed < 30; seed++) {
      final dungeon = make(seed);
      expect(
        dungeon.reachableFloorCount(),
        dungeon.totalFloorCount(),
        reason: 'seed $seed に到達できない床マスがある',
      );
    }
  });

  test('スタートと階段は歩けるマスで、別々の場所にある', () {
    for (var seed = 0; seed < 30; seed++) {
      final dungeon = make(seed);
      expect(
        dungeon.isWalkable(dungeon.startPosition.x, dungeon.startPosition.y),
        isTrue,
      );
      expect(
        dungeon.isWalkable(dungeon.stairsPosition.x, dungeon.stairsPosition.y),
        isTrue,
      );
      expect(dungeon.startPosition == dungeon.stairsPosition, isFalse);
    }
  });

  test('階段マスがちょうど1つ置かれている', () {
    final dungeon = make(123);
    var stairs = 0;
    for (var y = 0; y < dungeon.height; y++) {
      for (var x = 0; x < dungeon.width; x++) {
        if (dungeon.tiles[y][x] == TileType.stairsDown) stairs++;
      }
    }
    expect(stairs, 1);
  });

  test('地図のいちばん外側は必ず壁', () {
    final dungeon = make(7);
    for (var x = 0; x < dungeon.width; x++) {
      expect(dungeon.tiles[0][x], TileType.wall);
      expect(dungeon.tiles[dungeon.height - 1][x], TileType.wall);
    }
    for (var y = 0; y < dungeon.height; y++) {
      expect(dungeon.tiles[y][0], TileType.wall);
      expect(dungeon.tiles[y][dungeon.width - 1], TileType.wall);
    }
  });

  test('入るたびに地形が変わる（種が違えば地図も違う）', () {
    final a = make(1);
    final b = make(2);
    var diff = 0;
    for (var y = 0; y < a.height; y++) {
      for (var x = 0; x < a.width; x++) {
        if (a.tiles[y][x] != b.tiles[y][x]) diff++;
      }
    }
    expect(diff, greaterThan(0));
  });

  test('同じ種なら同じ地図（再現できる）', () {
    final a = make(42);
    final b = make(42);
    for (var y = 0; y < a.height; y++) {
      for (var x = 0; x < a.width; x++) {
        expect(a.tiles[y][x], b.tiles[y][x]);
      }
    }
  });
}
