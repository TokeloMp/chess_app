import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show compute; // NEW
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;
import 'app_text.dart';
import 'board_view.dart';
import 'chess_ai.dart'; 
import 'player_card.dart';

// Who is playing. Chosen in the New game dialog
enum GameMode {twoPlayers, computerEasy, computerNormal }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const Duration _startTime = Duration(minutes: 10);
  static const Duration _lowTime = Duration(seconds: 30);

  static const Map<String, int> _pieceValue = {
    'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9,
  };

  final ch.Chess _game = ch.Chess();
  final ScrollController _scroll = ScrollController();
  late final Timer _ticker;
  String? _selected;
  List<String> _targets = [];

  // Set when the match ends by resignation, agreed draw or timeout, which the
  // chess library knows nothing about. Null while the game is live.
  String? _result;

  // 
  GameMode _mode = GameMode.twoPlayers;

  Duration _whiteTime = _startTime;
  Duration _blackTime = _startTime;

  final List<String> _capturedByWhite = [];
  final List<String> _capturedByBlack = [];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _ticker.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // ---- derived state: computed from the game, never stored separately ----

  String get _side => _game.turn == ch.Color.WHITE ? 'White' : 'Black';
  String get _opponent => _game.turn == ch.Color.WHITE ? 'Black' : 'White';

  bool get _isOver => _result != null || _game.in_checkmate || _game.in_draw;

  bool get _clockRunning => _game.getHistory().isNotEmpty && !_isOver;

  // it is the computer's turn. Derived, so there is no "thinking" flag to
  // keep in sync: from the player's move until the reply, this is true.
  bool get _vsComputer => _mode != GameMode.twoPlayers;

  String get _computerName =>
      _mode == GameMode.computerEasy ? 'Computer (Easy)' : 'Computer (Normal)';

  bool get _isComputerTurn => _vsComputer && _game.turn == ch.Color.BLACK;


  bool _isActive(ch.Color color) => !_isOver && _game.turn == color;

  String get _statusText {
    if (_result != null) return _result!;
    if (_game.in_checkmate) return 'Checkmate — $_opponent wins';
    if (_game.in_stalemate) return 'Stalemate — draw';
    if (_game.insufficient_material) return 'Draw — insufficient material';
    if (_game.in_threefold_repetition) return 'Draw — threefold repetition';
    if (_game.in_draw) return 'Draw';
    if (_isComputerTurn) return 'Computer is thinking…'; // NEW
    return _game.in_check ? '$_side to move — check!' : '$_side to move';
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int _points(List<String> pieces) =>
      pieces.fold(0, (sum, type) => sum + (_pieceValue[type] ?? 0));

  int get _whiteLead => _points(_capturedByWhite) - _points(_capturedByBlack);

  List<String> _sorted(List<String> pieces) {
    const order = 'qrbnp';
    return [...pieces]..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
  }

  // ---- clock ----

  void _onTick() {
    if (!_clockRunning) return;
    setState(() {
      final whiteToMove = _game.turn == ch.Color.WHITE;
      final left =
          (whiteToMove ? _whiteTime : _blackTime) - const Duration(seconds: 1);
      if (whiteToMove) {
        _whiteTime = left;
      } else {
        _blackTime = left;
      }
      if (left <= Duration.zero) {
        _result = '$_side ran out of time — $_opponent wins';
        _selected = null;
        _targets = [];
      }
    });
  }

  // ---- dialog helpers ----

  Future<bool> _confirm({
    required String title,
    required String message,
    String yes = 'Yes',
    String no = 'Cancel',
  }) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppText.dialogTitle),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(no)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
        ],
      ),
    );
    return answer ?? false;
  }

    /// Asks who is playing. Returns null if the dialog was dismissed, which
  /// cancels the new game.
  Future<GameMode?> _chooseMode() {
    return showDialog<GameMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('New game', style: AppText.dialogTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, GameMode.twoPlayers),
            child: const Text('Two players', style: TextStyle(fontSize: 18)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, GameMode.computerEasy),
            child: const Text(
              'Computer: Easy (you are White)',
              style: TextStyle(fontSize: 18),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, GameMode.computerNormal),
            child: const Text(
              'Computer: Normal (you are White)',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ---- button actions ----

  Future<void> _newGame() async {
    final inProgress = _game.getHistory().isNotEmpty && !_isOver;
    if (inProgress) {
      final ok = await _confirm(
        title: 'Start a new game?',
        message: 'The current game will be lost.',
        yes: 'New game',
      );
      if (!ok || !mounted) return;
    }

    final mode = await _chooseMode(); 
    if (mode == null || !mounted) return; // dismissed: keep the current game

    setState(() {
      _game.reset();
      _selected = null;
      _targets = [];
      _result = null;
      _whiteTime = _startTime;
      _blackTime = _startTime;
      _capturedByWhite.clear();
      _capturedByBlack.clear();
      _mode = mode; 
    });
  }

  Future<void> _resign() async {
    // against the computer, the human (White) is the one resigning.
    final side = _vsComputer ? 'White' : _side;
    final opponent = _vsComputer ? 'Computer' : _opponent;
    final ok = await _confirm(
      title: '$side resigns?',
      message: 'This ends the game and $opponent wins.',
      yes: 'Resign',
    );
    if (!ok || !mounted || _isOver) return;
    setState(() {
      _result = '$side resigned — $opponent wins';
      _selected = null;
      _targets = [];
    });
  }

  Future<void> _offerDraw() async {
    final side = _side;
    final opponent = _opponent;
    final accepted = await _confirm(
      title: '$side offers a draw',
      message: '$opponent, do you accept?',
      yes: 'Accept',
      no: 'Decline',
    );
    if (!accepted || !mounted || _isOver) return;
    setState(() {
      _result = 'Draw by agreement';
      _selected = null;
      _targets = [];
    });
  }

  // ---- captured pieces ----

  Map<String, int> _countPieces(ch.Color color) {
    const files = 'abcdefgh';
    final counts = <String, int>{};
    for (var f = 0; f < 8; f++) {
      for (var rank = 1; rank <= 8; rank++) {
        final piece = _game.get('${files[f]}$rank');
        if (piece != null && piece.color == color) {
          counts[piece.type.name] = (counts[piece.type.name] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  /// Plays the move, and records the captured piece if there was one.
  void _makeMove(String from, String to, String promotion) {
    final mover = _game.turn;
    final opponent = mover == ch.Color.WHITE ? ch.Color.BLACK : ch.Color.WHITE;
    final before = _countPieces(opponent);

    _game.move({'from': from, 'to': to, 'promotion': promotion});

    final after = _countPieces(opponent);
    for (final type in before.keys) {
      if ((after[type] ?? 0) < before[type]!) {
        (mover == ch.Color.WHITE ? _capturedByWhite : _capturedByBlack).add(type);
      }
    }
  }

  // ---- computer player ----

  Future<List<String>?> _askComputer(String fen) async {
    final pick = _mode == GameMode.computerEasy ? chooseRandomMove : chooseMove;
    try {
      return await compute(pick, fen);
    } catch (_) {
      return compute(chooseRandomMove, fen);
    }
  }



  /// Asks the AI for a reply and plays it. Called after each human move.
  Future<void> _playComputerMove() async {
    if (!_isComputerTurn || _isOver) return;

    final fen = _game.fen; // remember the position we are answering

    // A short pause so the player's own move is visible before the reply.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // The search runs in a separate isolate so the screen never freezes.
    final move = await _askComputer(fen);
    if (!mounted) return;

    // The game may have changed while the computer was thinking (new game,
    // resignation, timeout). If so, throw the answer away.
    if (_game.fen != fen || _isOver || move == null) return;

    setState(() => _makeMove(move[0], move[1], 'q'));
    _scrollHistoryToEnd();
  }

  void _scrollHistoryToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  // ---- board interaction ----

  bool _isPromotion(String from, String to) {
    final piece = _game.get(from);
    if (piece == null || piece.type.name != 'p') return false;
    final lastRank = piece.color == ch.Color.WHITE ? '8' : '1';
    return to.endsWith(lastRank);
  }

  Future<String> _choosePromotion() async {
    const options = {
      'q': '♛  Queen',
      'r': '♜  Rook',
      'b': '♝  Bishop',
      'n': '♞  Knight',
    };
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: const Text('Promote pawn to…', style: AppText.dialogTitle),
        children: [
          for (final entry in options.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, entry.key),
              child: Text(entry.value, style: const TextStyle(fontSize: 20)),
            ),
        ],
      ),
    );
    return choice ?? 'q';
  }

  Future<void> _onSquareTap(String square) async {
    if (_isOver || _isComputerTurn) return; // ignore taps on the computer's turn

    // 1. A highlighted target square: make the move.
    if (_selected != null && _targets.contains(square)) {
      final from = _selected!;
      var promotion = 'q';

      if (_isPromotion(from, square)) {
        promotion = await _choosePromotion();
        if (!mounted || _isOver) return;
      }

      setState(() {
        _makeMove(from, square, promotion);
        _selected = null;
        _targets = [];
      });
      _scrollHistoryToEnd();
      _playComputerMove(); 
      return;
    }

    // 2. One of the current player's pieces: select it.
    final piece = _game.get(square);
    if (piece != null && piece.color == _game.turn) {
      final moves = _game.moves({'asObjects': true, 'square': square});
      setState(() {
        _selected = square;
        _targets = [for (final m in moves) m.toAlgebraic as String];
      });
      return;
    }

    // 3. Anything else: clear the selection.
    setState(() {
      _selected = null;
      _targets = [];
    });
  }

  // ---- UI pieces (each is built once here and reused by both layouts) ----

  Widget _buildBoard() {
    return BoardView(
      game: _game,
      selected: _selected,
      targets: _targets,
      onSquareTap: _onSquareTap,
    );
  }

  Widget _buildBlackCard() {
    return PlayerCard(
      name: _vsComputer ? _computerName : 'Black', 
      time: _format(_blackTime),
      isWhite: false,
      isActive: _isActive(ch.Color.BLACK),
      isLowTime: _blackTime < _lowTime,
      captured: _sorted(_capturedByBlack),
      advantage: -_whiteLead,
    );
  }

  Widget _buildWhiteCard() {
    return PlayerCard(
      name: 'White',
      time: _format(_whiteTime),
      isWhite: true,
      isActive: _isActive(ch.Color.WHITE),
      isLowTime: _whiteTime < _lowTime,
      captured: _sorted(_capturedByWhite),
      advantage: _whiteLead,
    );
  }

  Widget _buildStatus() {
    return Text(
      _statusText,
      textAlign: TextAlign.center,
      style: AppText.status,
    );
  }

  Widget _buildHistory() {
    final moves = _game.getHistory().cast<String>();

    if (moves.isEmpty) {
      return const Center(child: Text('No moves yet'));
    }

    final rowCount = (moves.length + 1) ~/ 2;

    return ListView.builder(
      controller: _scroll,
      itemCount: rowCount,
      itemBuilder: (context, i) {
        final whiteMove = moves[i * 2];
        final blackMove = i * 2 + 1 < moves.length ? moves[i * 2 + 1] : '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 36, child: Text('${i + 1}.')),
              Expanded(child: Text(whiteMove)),
              Expanded(child: Text(blackMove)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton(onPressed: _newGame, child: const Text('New game')),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            // the computer does not negotiate, so no draw offers against it.
            onPressed: (_isOver || _vsComputer) ? null : _offerDraw,
            child: const Text('Draw'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: _isOver ? null : _resign,
            child: const Text('Resign'),
          ),
        ),
      ],
    );
  }

  // ---- layouts ----

  Widget _buildNarrow(BoxConstraints c) {
    const reserved = 350.0;
    final side = math.min(c.maxWidth, math.max(c.maxHeight - reserved, 200.0));

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: side,
        child: Column(
          children: [
            _buildBlackCard(),
            const SizedBox(height: 8),
            SizedBox(width: side, height: side, child: _buildBoard()),
            const SizedBox(height: 8),
            _buildWhiteCard(),
            const SizedBox(height: 12),
            _buildStatus(),
            const SizedBox(height: 12),
            _buildButtons(),
            const SizedBox(height: 8),
            Expanded(child: _buildHistory()),
          ],
        ),
      ),
    );
  }

  Widget _buildWide(BoxConstraints c) {
    const gap = 24.0;
    const minPanelWidth = 300.0;
    final side = math.min(c.maxHeight, c.maxWidth - minPanelWidth - gap);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: side, height: side, child: _buildBoard()),
        const SizedBox(width: gap),
        Expanded(
          child: SizedBox(
            height: side,
            child: Column(
              children: [
                _buildBlackCard(),
                const SizedBox(height: 12),
                Expanded(child: _buildHistory()),
                const SizedBox(height: 12),
                _buildStatus(),
                const SizedBox(height: 12),
                _buildButtons(),
                const SizedBox(height: 12),
                _buildWhiteCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700 &&
                  constraints.maxWidth > constraints.maxHeight;
              return isWide ? _buildWide(constraints) : _buildNarrow(constraints);
            },
          ),
        ),
      ),
    );
  }
}