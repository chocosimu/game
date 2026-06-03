// ゲーム画面の基本動作テスト。
// 「キーを押すとキャラが動き、ターン数が増える」ことを確かめる。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:game/game_screen.dart';
import 'package:game/monster.dart';

void main() {
  testWidgets('最初はターン0で、移動キーを押すとターンが進む', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 種を固定して、毎回同じ地図でテストする。
    await tester.pumpWidget(const MaterialApp(home: GameScreen(seed: 1)));
    await tester.pump();

    expect(find.text('ターン 0'), findsOneWidget);

    // スタートは部屋の中心なので、右へは必ず動ける。
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.text('ターン 0'), findsNothing);
    expect(find.text('ターン 1'), findsOneWidget);
  });

  testWidgets('壁にぶつかると止まる（入力が全部成功するわけではない）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: GameScreen(seed: 1)));
    await tester.pump();

    const presses = 80;
    for (var i = 0; i < presses; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }

    // 右へ80回押しても、途中で必ず壁に当たるので80ターンには届かない。
    expect(find.text('ターン $presses'), findsNothing);
    // でも何回かは進めているので、0ターンのままではない。
    expect(find.text('ターン 0'), findsNothing);
  });

  testWidgets('画面の「→」ボタンをタップしても移動する', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: GameScreen(seed: 1)));
    await tester.pump();

    expect(find.text('ターン 0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dir_1_0')));
    await tester.pump();

    expect(find.text('ターン 1'), findsOneWidget);
  });

  testWidgets('HUDにレベル・HP・満腹度が表示される', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: GameScreen(seed: 1)));
    await tester.pump();

    expect(find.text('Lv 1'), findsOneWidget);
    expect(find.text('HP 15/15'), findsOneWidget);
    expect(find.text('満腹 100/100'), findsOneWidget);
  });

  testWidgets('右隣の敵に向かって動くと「攻撃」になり、倒すと経験値が入る', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: GameScreen(seed: 1)));
    await tester.pump();

    final state = tester.state<GameScreenState>(find.byType(GameScreen));
    // フロアに最初からいる敵をどけて、検証を1匹だけに絞る。
    state.debugMonsters.clear();
    // スタートは部屋の中心なので右隣は床。そこにスライムを置く。
    state.debugSpawnMonster(MonsterKind.slime, 1, 0);
    await tester.pump();
    expect(state.debugMonsters.length, 1);

    // 右を押す＝敵マスへ動こうとする＝攻撃。命中92%なので外れることもあるが、
    // 何回か押せば必ず倒せる（隣接スライムは動かず殴り合いになる）。
    var guard = 0;
    while (state.debugMonsters.isNotEmpty && guard < 12) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      guard++;
    }

    expect(state.debugMonsters.isEmpty, true); // 倒した敵は片づけられる
    expect(state.debugPlayer.exp, MonsterKind.slime.exp); // EXPが入った（1匹=2）
    expect(find.textContaining('倒した'), findsOneWidget); // ログが出る
  });

  testWidgets('中央の「・」ボタンで足踏みするとターンだけ進む', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: GameScreen(seed: 1)));
    await tester.pump();

    final state = tester.state<GameScreenState>(find.byType(GameScreen));
    state.debugMonsters.clear(); // 敵に邪魔されずに足踏みだけを見る
    final (sx, sy) = (state.debugPlayerX, state.debugPlayerY);

    expect(find.text('ターン 0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wait')));
    await tester.pumpAndSettle();

    // その場にとどまったまま、ターンだけ進む。
    expect(state.debugPlayerX, sx);
    expect(state.debugPlayerY, sy);
    expect(find.text('ターン 1'), findsOneWidget);
    expect(find.textContaining('待った'), findsOneWidget);
  });

  testWidgets('敵の攻撃でHPが0になると「倒れた」画面が出る', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: GameScreen(seed: 1)));
    await tester.pump();

    final state = tester.state<GameScreenState>(find.byType(GameScreen));
    state.debugMonsters.clear(); // 最初からいる敵をどけて1匹に絞る
    // 一撃では倒せない頑丈で強い敵を右隣に置く（反撃で大ダメージ）。
    const tough = MonsterKind(
      name: 'つよいの',
      maxHp: 999,
      attack: 80,
      defense: 0,
      exp: 0,
      color: 0xFFFF0000,
    );
    state.debugSpawnMonster(tough, 1, 0);
    state.debugSetPlayerHp(3); // あと少しで倒れる
    await tester.pump();

    // 右を押す＝敵を攻撃（倒せない）→ 敵が反撃。命中92%なので、
    // 数ターン押せば必ず反撃が当たって HP0 → 倒れる。
    var guard = 0;
    while (!state.debugDefeated && guard < 12) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      guard++;
    }

    expect(state.debugDefeated, true);
    expect(find.text('倒れてしまった…'), findsOneWidget);
    expect(find.text('最初からやり直す'), findsOneWidget);

    // 「最初からやり直す」を押すと、Lv1・HP満タンに戻り、画面も消える。
    await tester.tap(find.text('最初からやり直す'));
    await tester.pumpAndSettle();
    expect(state.debugDefeated, false);
    expect(state.debugPlayer.level, 1);
    expect(state.debugPlayer.hp, state.debugPlayer.maxHp);
    expect(find.text('倒れてしまった…'), findsNothing);
  });
}
