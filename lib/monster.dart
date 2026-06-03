/// モンスターの「種類（設計図）」。
///
/// トルネコには約186種いるが、今はまだ「スライム」1種だけ。
/// 名前と基本ステータス（その敵に最初に出会うフロアでの値）を持つ。
/// 攻撃力・防御力・経験値は“箱に入れておくだけ”で、実際に使うのは戦闘の段階。
class MonsterKind {
  const MonsterKind({
    required this.name,
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.exp,
    required this.color,
  });

  final String name; // 名前
  final int maxHp; // 最大HP
  final int attack; // 攻撃力（戦闘の段階で使う）
  final int defense; // 防御力
  final int exp; // 倒したときにもらえる経験値
  final int color; // 画面で描くときの色（0xAARRGGBB 形式）

  /// スライム（1〜3F で出会う値・データ正本より）。
  static const MonsterKind slime = MonsterKind(
    name: 'スライム',
    maxHp: 5,
    attack: 3,
    defense: 0,
    exp: 2,
    color: 0xFF4FC3F7, // 水色
  );
}

/// 実際にフロアにいる1匹のモンスター。
/// 「種類（設計図）」＋「今いる座標」＋「今のHP」を持つ。
class Monster {
  Monster({required this.kind, required this.x, required this.y})
      : hp = kind.maxHp;

  final MonsterKind kind;
  int x;
  int y;
  int hp;

  bool get isAlive => hp > 0;
}
