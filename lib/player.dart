import 'dart:math';

import 'combat.dart';

/// プレイヤー（トルネコ）の状態をまとめて持つ「箱」。
///
/// 第1段階まではプレイヤーは画面上の「座標だけ」だったが、
/// ここに“生きるための数字”（HP・満腹度・レベルなど）を持たせる。
/// 初期値は docs/torneko3_reference.md（データ正本）に合わせている。
class Player {
  Player({
    this.level = 1,
    this.exp = 0,
    this.maxHp = 15, // Lv1 の最大HP（実測で確定）
    int? hp,
    this.maxFullness = 100, // 満腹度の初期最大（%）
    int? fullness,
    this.strength = 8, // 初期ちから（資料で確定）
  })  : hp = hp ?? maxHp,
        fullness = fullness ?? maxFullness;

  int level; // レベル
  int exp; // 累積の経験値
  int maxHp; // 最大HP
  int hp; // 今のHP
  int maxFullness; // 満腹度の最大
  int fullness; // 今の満腹度
  int strength; // ちから

  // 満腹度が1減るまでの歩数を内部で数える（10歩ごとに1%減る）。
  int _stepCounter = 0;
  static const int stepsPerFullness = 10;

  // HPの自然回復は「最大HP÷150」と小さい。毎ターン「最大HP」をためていき、
  // 150たまるごとに1回復する（整数だけで正確に数える）。§1.2。
  int _hpRegenAccum = 0;
  static const int hpRegenDivisor = 150;

  /// レベルまでの経験値表での「いまのレベルの開始EXP」。
  int get expForCurrentLevel => cumulativeExpTable[(level - 1)
      .clamp(0, cumulativeExpTable.length - 1)];

  /// 次のレベルになるのに必要な「累積EXP」。最大レベルなら今の値を返す。
  int get expForNextLevel => level >= maxLevel
      ? cumulativeExpTable.last
      : cumulativeExpTable[level]; // index=level が「次のLv」

  /// 生きているか（HPが1以上）。
  bool get isAlive => hp > 0;

  /// HPの割合（0.0〜1.0）。HUDのバー表示に使う。
  double get hpRatio => maxHp == 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);

  /// 満腹度の割合（0.0〜1.0）。
  double get fullnessRatio =>
      maxFullness == 0 ? 0 : (fullness / maxFullness).clamp(0.0, 1.0);

  /// 1ターン（1歩・1行動）進んだときの満腹度・HP処理。
  ///
  /// ・満腹度があるとき … 10歩ごとに満腹度を1減らし、HPを少し自然回復する。
  /// ・満腹度が0のとき … 代わりに毎ターンHPが1減る（空腹のダメージ）。
  void onStep() {
    if (fullness > 0) {
      _stepCounter++;
      if (_stepCounter >= stepsPerFullness) {
        _stepCounter = 0;
        fullness--;
      }
      // HP自然回復（§1.2）：毎ターン「最大HP÷150」回復。端数は内部にためる。
      if (hp < maxHp) {
        _hpRegenAccum += maxHp;
        while (_hpRegenAccum >= hpRegenDivisor && hp < maxHp) {
          hp++;
          _hpRegenAccum -= hpRegenDivisor;
        }
      }
    } else if (hp > 0) {
      hp--;
    }
  }

  /// 経験値を得る。レベルが上がったら、その回数だけ最大HPを乱数で成長させる（§1.1/§1.2）。
  /// 上がったレベル数（0以上）を返す。0なら「レベルアップしなかった」。
  int gainExp(int amount, Random random) {
    exp += amount;
    final newLevel = levelForExp(exp);
    var ups = 0;
    while (level < newLevel && level < maxLevel) {
      level++;
      final grow = hpGrowth(random);
      maxHp = (maxHp + grow).clamp(0, maxHpCap);
      // レベルアップで今のHPもその分だけ増える（上限は最大HP）。
      hp = (hp + grow).clamp(0, maxHp);
      ups++;
    }
    return ups;
  }
}
