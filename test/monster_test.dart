// モンスター（スライム）のデータの基本テスト。

import 'package:flutter_test/flutter_test.dart';
import 'package:game/monster.dart';

void main() {
  test('スライムの設計図がデータ正本どおり', () {
    const slime = MonsterKind.slime;
    expect(slime.name, 'スライム');
    expect(slime.maxHp, 5);
    expect(slime.attack, 3);
    expect(slime.defense, 0);
    expect(slime.exp, 2);
  });

  test('生成した1匹はHP満タンで生きている', () {
    final m = Monster(kind: MonsterKind.slime, x: 3, y: 4);
    expect(m.x, 3);
    expect(m.y, 4);
    expect(m.hp, MonsterKind.slime.maxHp);
    expect(m.isAlive, true);
  });

  test('HPが0なら倒れている', () {
    final m = Monster(kind: MonsterKind.slime, x: 0, y: 0)..hp = 0;
    expect(m.isAlive, false);
  });
}
