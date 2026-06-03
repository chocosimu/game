// プレイヤーの状態（HP・満腹度・レベル）の基本テスト。

import 'package:flutter_test/flutter_test.dart';
import 'package:game/player.dart';

void main() {
  test('初期値はデータ正本どおり（Lv1・HP15・満腹度100・ちから8）', () {
    final p = Player();
    expect(p.level, 1);
    expect(p.maxHp, 15);
    expect(p.hp, 15);
    expect(p.maxFullness, 100);
    expect(p.fullness, 100);
    expect(p.strength, 8);
    expect(p.exp, 0);
    expect(p.isAlive, true);
  });

  test('10歩あるくと満腹度が1減る', () {
    final p = Player();
    for (var i = 0; i < 9; i++) {
      p.onStep();
    }
    expect(p.fullness, 100); // 9歩ではまだ減らない
    p.onStep(); // 10歩目で減る
    expect(p.fullness, 99);
  });

  test('満腹度が0のときは1歩ごとにHPが1減る', () {
    final p = Player(fullness: 0);
    expect(p.hp, 15);
    p.onStep();
    expect(p.fullness, 0);
    expect(p.hp, 14);
  });

  test('HPの割合・満腹度の割合が正しい', () {
    final p = Player(hp: 6, fullness: 50);
    expect(p.hpRatio, closeTo(6 / 15, 1e-9));
    expect(p.fullnessRatio, closeTo(0.5, 1e-9));
  });
}
