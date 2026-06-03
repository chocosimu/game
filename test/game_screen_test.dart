// ゲーム画面の基本動作テスト。
// 「キーを押すとキャラが動き、ターン数が増える」ことを確かめる。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:game/game_screen.dart';

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
}
