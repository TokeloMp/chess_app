import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:chess/chess.dart' as ch;

class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.game,
    required this.onSquareTap,
    this.selected,
    this.targets = const [],
  });

  final ch.Chess game; // the position to draw
  final String? selected; // currently selected square, if any
  final List<String> targets; // squares to mark as legal destinations
  final void Function(String square) onSquareTap; // called when a square is tapped

  static const Color lightSquare = Color(0xFFF0E2CC); // sand
  static const Color darkSquare = Color(0xFFC1694F); // terracotta
  static const Color selectedSquare = Color(0xFFE3B778); // warm gold
  static const Color dotColor = Color(0x802B1D16); // 50% transparent brown

  /// Returns the image for the piece on [square] (e.g. 'e4'), or null if empty.
  Widget? _pieceAt(String square) {
    final piece = game.get(square);
    if (piece == null) return null;

    final colour = piece.color == ch.Color.WHITE ? 'w' : 'b';
    final type = piece.type.name.toUpperCase(); // 'k' -> 'K'

    return Padding(
      padding: const EdgeInsets.all(2),
      child: SvgPicture.asset('assets/pieces/$colour$type.svg'),
    );
  }

  @override
  Widget build(BuildContext context) {
    const files = 'abcdefgh';

    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: List.generate(8, (row) {
          return Expanded(
            child: Row(
              children: List.generate(8, (col) {
                final isLight = (row + col) % 2 == 0;
                final square = '${files[col]}${8 - row}'; // row 0 = rank 8
                final isSelected = square == selected;
                final isTarget = targets.contains(square);
                final piece = _pieceAt(square);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSquareTap(square),
                    child: Container(
                      color: isSelected
                          ? selectedSquare
                          : (isLight ? lightSquare : darkSquare),
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          if (piece != null) piece,
                          if (isTarget)
                            const Center(
                              child: FractionallySizedBox(
                                widthFactor: 0.3,
                                heightFactor: 0.3,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}