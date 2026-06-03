// プレイヤーの状態（HP・満腹度・レベル）の基本テスト。

import 'dart:math';

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

  test('経験値を得るとレベルが上がり、最大HPが増える', () {
    final p = Player();
    final ups = p.gainExp(10, Random(1)); // Lv2に必要な累積EXPちょうど
    expect(ups, 1);
    expect(p.level, 2);
    expect(p.exp, 10);
    // 最大HPは 15 + (3〜7) の範囲に増える
    expect(p.maxHp, inInclusiveRange(18, 22));
  });

  test('スライム1匹(EXP2)ではまだレベルは上がらない', () {
    final p = Player();
    final ups = p.gainExp(2, Random(1));
    expect(ups, 0);
    expect(p.level, 1);
    expect(p.exp, 2);
  });

  test('HPが減っていると歩くたびに少しずつ自然回復する（満腹度がある間）', () {
    // 最大HP15なら毎ターン 15/150=0.1 回復 → 10ターンで1回復。
    final p = Player(hp: 5);
    for (var i = 0; i < 10; i++) {
      p.onStep();
    }
    expect(p.hp, 6);
  });

  test('満腹度0のときは自然回復せず、逆にHPが減る', () {
    final p = Player(hp: 10, fullness: 0);
    p.onStep();
    expect(p.hp, 9);
  });
}
