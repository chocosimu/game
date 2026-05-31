import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const TicTacToeApp());
}

/// Root application widget.
class TicTacToeApp extends StatelessWidget {
  const TicTacToeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Tic-Tac-Toe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const GamePage(),
    );
  }
}

/// Who is playing against whom.
enum GameMode { vsComputer, twoPlayer }

/// How clever the computer is.
enum Difficulty { easy, hard }

/// The two marks used on the board.
class Marks {
  static const String x = 'X';
  static const String o = 'O';
}

/// The 8 possible winning lines on a 3x3 board.
const List<List<int>> _winningLines = <List<int>>[
  [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
  [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
  [0, 4, 8], [2, 4, 6], // diagonals
];

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  /// The board: 9 cells, each null, 'X' or 'O'.
  List<String?> _board = List<String?>.filled(9, null);

  /// Whose turn it is. The human is always 'X' and moves first.
  String _current = Marks.x;

  GameMode _mode = GameMode.vsComputer;
  Difficulty _difficulty = Difficulty.hard;

  /// The winning line to highlight, or null while the game is in progress.
  List<int>? _winningLine;
  bool _isDraw = false;
  bool _aiThinking = false;

  // Running scores across rounds.
  int _scoreX = 0;
  int _scoreO = 0;
  int _scoreDraw = 0;

  final Random _rng = Random();

  bool get _gameOver => _winningLine != null || _isDraw;
  String? get _winner =>
      _winningLine == null ? null : _board[_winningLine!.first];

  // ---- Game logic -------------------------------------------------------

  void _handleTap(int index) {
    if (_gameOver || _aiThinking || _board[index] != null) return;
    // In vs-computer mode the human only controls X.
    if (_mode == GameMode.vsComputer && _current != Marks.x) return;

    setState(() => _place(index, _current));

    if (_gameOver) return;

    if (_mode == GameMode.vsComputer && _current == Marks.o) {
      _scheduleAiMove();
    }
  }

  void _place(int index, String mark) {
    _board[index] = mark;
    final line = _findWinningLine(_board);
    if (line != null) {
      _winningLine = line;
      _recordResult(mark);
    } else if (!_board.contains(null)) {
      _isDraw = true;
      _scoreDraw++;
    } else {
      _current = mark == Marks.x ? Marks.o : Marks.x;
    }
  }

  void _recordResult(String winner) {
    if (winner == Marks.x) {
      _scoreX++;
    } else {
      _scoreO++;
    }
  }

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    // A short, human-feeling pause before the computer plays.
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || _gameOver) return;
      final move = _chooseAiMove();
      setState(() {
        _aiThinking = false;
        if (move != null) _place(move, Marks.o);
      });
    });
  }

  int? _chooseAiMove() {
    final empties = <int>[
      for (int i = 0; i < 9; i++)
        if (_board[i] == null) i,
    ];
    if (empties.isEmpty) return null;

    // Easy: play randomly. Hard: play perfectly with minimax.
    if (_difficulty == Difficulty.easy) {
      return empties[_rng.nextInt(empties.length)];
    }
    return _bestMove(List<String?>.of(_board));
  }

  /// Returns the optimal move for 'O' using the minimax algorithm.
  int _bestMove(List<String?> board) {
    int bestScore = -1000;
    final bestMoves = <int>[];
    for (int i = 0; i < 9; i++) {
      if (board[i] != null) continue;
      board[i] = Marks.o;
      final score = _minimax(board, isMaximizing: false, depth: 0);
      board[i] = null;
      if (score > bestScore) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(i);
      } else if (score == bestScore) {
        bestMoves.add(i);
      }
    }
    // Pick randomly among equally-good moves so the AI is not predictable.
    return bestMoves[_rng.nextInt(bestMoves.length)];
  }

  int _minimax(
    List<String?> board, {
    required bool isMaximizing,
    required int depth,
  }) {
    final line = _findWinningLine(board);
    if (line != null) {
      // Prefer faster wins and slower losses via the depth term.
      return board[line.first] == Marks.o ? 10 - depth : depth - 10;
    }
    if (!board.contains(null)) return 0;

    if (isMaximizing) {
      int best = -1000;
      for (int i = 0; i < 9; i++) {
        if (board[i] != null) continue;
        board[i] = Marks.o;
        best = max(best, _minimax(board, isMaximizing: false, depth: depth + 1));
        board[i] = null;
      }
      return best;
    } else {
      int best = 1000;
      for (int i = 0; i < 9; i++) {
        if (board[i] != null) continue;
        board[i] = Marks.x;
        best = min(best, _minimax(board, isMaximizing: true, depth: depth + 1));
        board[i] = null;
      }
      return best;
    }
  }

  List<int>? _findWinningLine(List<String?> board) {
    for (final line in _winningLines) {
      final first = board[line[0]];
      if (first != null && first == board[line[1]] && first == board[line[2]]) {
        return line;
      }
    }
    return null;
  }

  // ---- Controls ---------------------------------------------------------

  void _newRound() {
    setState(() {
      _board = List<String?>.filled(9, null);
      _current = Marks.x;
      _winningLine = null;
      _isDraw = false;
      _aiThinking = false;
    });
  }

  void _resetScores() {
    setState(() {
      _scoreX = 0;
      _scoreO = 0;
      _scoreDraw = 0;
    });
    _newRound();
  }

  void _changeMode(GameMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    _newRound();
  }

  void _changeDifficulty(Difficulty difficulty) {
    if (difficulty == _difficulty) return;
    setState(() => _difficulty = difficulty);
    _newRound();
  }

  // ---- UI ---------------------------------------------------------------

  String get _statusText {
    if (_winner != null) {
      if (_mode == GameMode.vsComputer) {
        return _winner == Marks.x ? 'You win! 🎉' : 'Computer wins 🤖';
      }
      return 'Player $_winner wins! 🎉';
    }
    if (_isDraw) return "It's a draw 🤝";
    if (_aiThinking) return 'Computer is thinking…';
    if (_mode == GameMode.vsComputer) {
      return _current == Marks.x ? 'Your turn' : 'Computer turn';
    }
    return "Player $_current's turn";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.55),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTitle(scheme),
                      const SizedBox(height: 20),
                      _buildModeSelector(),
                      if (_mode == GameMode.vsComputer) ...[
                        const SizedBox(height: 12),
                        _buildDifficultySelector(),
                      ],
                      const SizedBox(height: 20),
                      _buildScoreboard(scheme),
                      const SizedBox(height: 16),
                      _buildStatusBanner(scheme),
                      const SizedBox(height: 16),
                      _buildBoard(scheme),
                      const SizedBox(height: 24),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(ColorScheme scheme) {
    return Column(
      children: [
        Text(
          'Tic-Tac-Toe',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '○× ゲーム',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<GameMode>(
      segments: const [
        ButtonSegment(
          value: GameMode.vsComputer,
          label: Text('vs Computer'),
          icon: Icon(Icons.smart_toy_outlined),
        ),
        ButtonSegment(
          value: GameMode.twoPlayer,
          label: Text('2 Players'),
          icon: Icon(Icons.people_outline),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (s) => _changeMode(s.first),
    );
  }

  Widget _buildDifficultySelector() {
    return SegmentedButton<Difficulty>(
      segments: const [
        ButtonSegment(value: Difficulty.easy, label: Text('Easy')),
        ButtonSegment(value: Difficulty.hard, label: Text('Hard')),
      ],
      selected: {_difficulty},
      onSelectionChanged: (s) => _changeDifficulty(s.first),
    );
  }

  Widget _buildScoreboard(ColorScheme scheme) {
    final xLabel = _mode == GameMode.vsComputer ? 'You (X)' : 'Player X';
    final oLabel = _mode == GameMode.vsComputer ? 'CPU (O)' : 'Player O';
    return Row(
      children: [
        Expanded(
          child: _ScoreCard(
            label: xLabel,
            score: _scoreX,
            color: _xColor,
            highlight: !_gameOver && _current == Marks.x,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ScoreCard(
            label: 'Draws',
            score: _scoreDraw,
            color: scheme.onSurfaceVariant,
            highlight: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ScoreCard(
            label: oLabel,
            score: _scoreO,
            color: _oColor,
            highlight: !_gameOver && _current == Marks.o,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(ColorScheme scheme) {
    final isWin = _winner != null;
    final bg = isWin
        ? (_winner == Marks.x ? _xColor : _oColor).withValues(alpha: 0.15)
        : scheme.surfaceContainerHighest;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_aiThinking) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              _statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(ColorScheme scheme) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, i) => _buildCell(i, scheme),
        ),
      ),
    );
  }

  Widget _buildCell(int index, ColorScheme scheme) {
    final mark = _board[index];
    final isWinning = _winningLine?.contains(index) ?? false;
    final markColor = mark == Marks.x ? _xColor : _oColor;

    final Color cellColor;
    if (isWinning) {
      cellColor = markColor.withValues(alpha: 0.22);
    } else {
      cellColor = scheme.surface;
    }

    return GestureDetector(
      key: ValueKey('cell-$index'),
      onTap: () => _handleTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isWinning ? markColor : scheme.outlineVariant,
            width: isWinning ? 2.5 : 1.2,
          ),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: mark == null
                ? const SizedBox.shrink()
                : Text(
                    mark,
                    key: ValueKey('$index-$mark'),
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: markColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _newRound,
            icon: const Icon(Icons.refresh),
            label: const Text('New Round'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _resetScores,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Reset Scores'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

const Color _xColor = Color(0xFFE53935); // red for X
const Color _oColor = Color(0xFF1E88E5); // blue for O

/// A small card showing one player's name and current score.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.score,
    required this.color,
    required this.highlight,
  });

  final String label;
  final int score;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.14)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
