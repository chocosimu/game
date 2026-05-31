// Widget tests for the (legacy) Tic-Tac-Toe game.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:game/legacy/tic_tac_toe.dart';

void main() {
  Finder cell(int index) => find.byKey(ValueKey('cell-$index'));

  // The full layout is taller than the default 800x600 test viewport, so we
  // pump the app onto a taller surface to keep every cell and button on-screen.
  Future<void> pumpGame(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const TicTacToeApp());
  }

  testWidgets('renders the title and an empty 3x3 board', (tester) async {
    await pumpGame(tester);

    expect(find.text('Tic-Tac-Toe'), findsOneWidget);
    for (var i = 0; i < 9; i++) {
      expect(cell(i), findsOneWidget);
    }
  });

  testWidgets('two players place X and O on alternating turns',
      (tester) async {
    await pumpGame(tester);

    // Switch to 2-player mode so no asynchronous computer move happens.
    await tester.tap(find.text('2 Players'));
    await tester.pumpAndSettle();

    await tester.tap(cell(0));
    await tester.pumpAndSettle();
    expect(find.text('X'), findsOneWidget);

    await tester.tap(cell(1));
    await tester.pumpAndSettle();
    expect(find.text('O'), findsOneWidget);
  });

  testWidgets('a completed row is detected as a win', (tester) async {
    await pumpGame(tester);

    await tester.tap(find.text('2 Players'));
    await tester.pumpAndSettle();

    // X takes the top row (0,1,2); O plays the middle row (3,4).
    for (final index in [0, 3, 1, 4, 2]) {
      await tester.tap(cell(index));
      await tester.pumpAndSettle();
    }

    expect(find.text('Player X wins! 🎉'), findsOneWidget);
  });

  testWidgets('the computer responds with a move in vs-computer mode',
      (tester) async {
    await pumpGame(tester);

    // Default mode is vs-computer; the human plays X first.
    await tester.tap(cell(4));
    await tester.pumpAndSettle();

    // After the human's move and the computer's reply, an O should appear.
    expect(find.text('O'), findsOneWidget);
  });

  testWidgets('New Round clears the board', (tester) async {
    await pumpGame(tester);

    await tester.tap(find.text('2 Players'));
    await tester.pumpAndSettle();

    await tester.tap(cell(0));
    await tester.pumpAndSettle();
    expect(find.text('X'), findsOneWidget);

    await tester.tap(find.text('New Round'));
    await tester.pumpAndSettle();
    expect(find.text('X'), findsNothing);
  });
}
