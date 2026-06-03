// 戦闘の「計算」（combat.dart）のテスト。
// 数字がデータ正本（docs/torneko3_reference.md）の式・表どおりかを確かめる。

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/combat.dart';

void main() {
  test('レベル攻撃力の表が正本どおり（§1.1）', () {
    expect(levelAttackTable.length, 99);
    expect(levelAttackFor(1), 5);
    expect(levelAttackFor(2), 8);
    expect(levelAttackFor(3), 11);
    expect(levelAttackFor(10), 31);
    expect(levelAttackFor(50), 100);
    expect(levelAttackFor(99), 150);
    // 範囲外でも落ちない（端で止まる）。
    expect(levelAttackFor(0), 5);
    expect(levelAttackFor(120), 150);
  });

  test('累積経験値の表とレベル判定が正本どおり（§1.1）', () {
    expect(cumulativeExpTable.length, 99);
    expect(cumulativeExpTable.last, 9990000);
    expect(levelForExp(0), 1);
    expect(levelForExp(9), 1); // Lv2にはまだ届かない
    expect(levelForExp(10), 2); // Lv2の必要量ちょうど
    expect(levelForExp(39), 2);
    expect(levelForExp(40), 3); // Lv3
    expect(levelForExp(15000), 20);
    expect(levelForExp(99999999), 99); // どれだけ多くてもLv99で頭打ち
  });

  test('基本攻撃力は §1.6 の式どおり（素手Lv1・ちから8＝7.5）', () {
    // 5 ×{1 +（8 + 0）/16}＝5 ×1.5＝7.5
    expect(baseAttackPower(levelAttackFor(1), 8), closeTo(7.5, 1e-9));
    // ちから16なら 5 ×{1 + 16/16}＝5 ×2＝10
    expect(baseAttackPower(5, 16), closeTo(10.0, 1e-9));
  });

  test('防御で基本ダメージが減る（§1.6・係数35/36）', () {
    // 防御0なら素通り
    expect(baseDamage(7.5, 0), closeTo(7.5, 1e-9));
    // 防御1なら ×(35/36)
    expect(baseDamage(36, 1), closeTo(35, 1e-9));
  });

  test('実ダメージは基本×(7/8〜9/8)の範囲に収まり、最低1', () {
    final rnd = Random(12345);
    for (var i = 0; i < 500; i++) {
      final d = rollDamage(8.0, rnd);
      // 8×7/8=7 〜 8×9/8=9 → floor で 7〜9
      expect(d, inInclusiveRange(7, 9));
    }
    // 基本ダメージが小さくても最低1は入る
    expect(rollDamage(0.1, Random(1)), 1);
  });

  test('HP成長は +3〜+7 の範囲（§1.2）', () {
    final rnd = Random(7);
    for (var i = 0; i < 1000; i++) {
      expect(hpGrowth(rnd), inInclusiveRange(3, 7));
    }
  });

  test('素手Lv1でスライム(HP5,防0)は1発で倒せる強さ', () {
    final atk = baseAttackPower(levelAttackFor(1), 8); // 7.5
    final base = baseDamage(atk, MonsterDefenseForTest.slimeDefense); // 7.5
    // 最小ダメージでも 7.5×7/8=6.56→6 ≥ 5
    final minDmg = (base * 7 / 8).floor();
    expect(minDmg, greaterThanOrEqualTo(5));
  });
}

/// テスト内で使うスライムの防御（monster.dart に依存させないための定数）。
class MonsterDefenseForTest {
  static const int slimeDefense = 0;
}
