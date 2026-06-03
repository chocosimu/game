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

  /// 生きているか（HPが1以上）。
  bool get isAlive => hp > 0;

  /// HPの割合（0.0〜1.0）。HUDのバー表示に使う。
  double get hpRatio => maxHp == 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);

  /// 満腹度の割合（0.0〜1.0）。
  double get fullnessRatio =>
      maxFullness == 0 ? 0 : (fullness / maxFullness).clamp(0.0, 1.0);

  /// 1ターン（1歩）進んだときの満腹度・HP処理。
  ///
  /// ・満腹度があるとき … 10歩ごとに満腹度を1減らす。
  /// ・満腹度が0のとき … 代わりに毎ターンHPが1減る（空腹のダメージ）。
  /// ※倒れた（HP0）ときの演出は、戦闘の段階でまとめて作る。
  void onStep() {
    if (fullness > 0) {
      _stepCounter++;
      if (_stepCounter >= stepsPerFullness) {
        _stepCounter = 0;
        fullness--;
      }
    } else if (hp > 0) {
      hp--;
    }
  }
}
