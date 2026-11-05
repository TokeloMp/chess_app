import 'dart:math' as math;
import 'package:chess/chess.dart' as ch;

/// Piece values in centipawns (100 = one pawn). The king is never captured, so it needs no value.
const Map<String, int> _pieceValue = {
  'p': 100,
  'n': 320,
  'b': 330,
  'r': 500,
  'q': 900,
  'k': 0,
};

/// Score used for checkmate. Far bigger than any material total.
const int _mate = 100000;

/// Scores [game] from [aiColor]'s point of view: positive is good for the
/// computer, negative is good for its opponent.
int _evaluate(ch.Chess game, ch.Color aiColor) {
  if (game.in_checkmate) {
    // The side to move is the one that has been mated.
    return game.turn == aiColor ? -_mate : _mate;
  }
  if (game.in_draw) return 0;

  const files = 'abcdefgh';
  var score = 0;
  for (var f = 0; f < 8; f++) {
    for (var rank = 1; rank <= 8; rank++) {
      final piece = game.get('${files[f]}$rank');
      if (piece == null) continue;
      final value = _pieceValue[piece.type.name] ?? 0;
      score += piece.color == aiColor ? value : -value;
    }
  }
  return score;
}

/// Every legal move in [game], as [from, to] pairs such as ['e2', 'e4'].
List<List<String>> _legalMoves(ch.Chess game) {
  final moves = game.moves({'asObjects': true});
  return [
    for (final m in moves) [m.fromAlgebraic as String, m.toAlgebraic as String],
  ];
}

/// A copy of [game] with [move] played, leaving the original untouched.
ch.Chess _after(ch.Chess game, List<String> move) {
  final next = ch.Chess.fromFEN(game.fen);
  next.move({'from': move[0], 'to': move[1], 'promotion': 'q'});
  return next;
}

/// Chooses a move for the side to move in the position [fen].

/// Looks two half-moves ahead (the computer's move, then the opponent's best reply) and keeps the move whose worst case is best. Returns ['from', 'to'], or null if there is no legal move.

/// This is a top-level function that only takes and returns simple values, so it can run in a separate isolate with `compute`.
List<String>? chooseMove(String fen) {
  final game = ch.Chess.fromFEN(fen);
  final aiColor = game.turn;

  final moves = _legalMoves(game);
  if (moves.isEmpty) return null;

  var bestScore = -_mate * 2;
  final bestMoves = <List<String>>[];

  for (final move in moves) {
    final afterMine = _after(game, move);

    int score;
    if (afterMine.in_checkmate || afterMine.in_draw) {
      score = _evaluate(afterMine, aiColor);
    } else {
      // Assume the opponent replies with whatever is worst for the computer.
      score = _mate * 2;
      for (final reply in _legalMoves(afterMine)) {
        final replyScore = _evaluate(_after(afterMine, reply), aiColor);
        if (replyScore < score) score = replyScore;
      }
    }

    if (score > bestScore) {
      bestScore = score;
      bestMoves.clear();
      bestMoves.add(move);
    } else if (score == bestScore) {
      bestMoves.add(move);
    }
  }

  // Several moves can tie, so pick one at random to avoid repeating games.
  return bestMoves[math.Random().nextInt(bestMoves.length)];
}

// Easy level: any legal move, chosen at random. Returns ['from','to'], or null if there is no legal move. Like [chooseMove], it is a top-level function with simple inputs and outputs so 'compute' can run it.
List<String>? chooseRandomMove(String fen) {
  final moves = _legalMoves(ch.Chess.fromFEN(fen));
  if (moves.isEmpty) return null;
  return moves[math.Random().nextInt(moves.length)];
}