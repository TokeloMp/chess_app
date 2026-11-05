import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_text.dart';

class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.name,
    required this.time,
    required this.isWhite,
    required this.isActive,
    this.isLowTime = false,
    this.captured = const [],
    this.advantage = 0,
  });

  final String name;
  final String time; // already formatted, e.g. '09:41'
  final bool isWhite; // which colour this player controls
  final bool isActive; // is it this player's turn?
  final bool isLowTime; // show the clock in red
  final List<String> captured; // piece types this player has taken, e.g. ['q', 'p']
  final int advantage; // material lead in points; shown only when above 0

  static const Color terracotta = Color(0xFFC1694F);
  static const Color ink = Color(0xFF2B1D16);

  @override
  Widget build(BuildContext context) {
    // The pieces this player captured belong to the OPPONENT, so they are
    // drawn in the opposite colour.
    final capturedColour = isWhite ? 'b' : 'w';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EADB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? terracotta : const Color(0xFFE3D6BE),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isWhite ? const Color(0xFFFAF6EE) : ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: ink, width: 1.5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: AppText.playerName)),
              Text(
                time,
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: isLowTime ? const Color(0xFFB3261E) : ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Fixed height: the card keeps the same size before and after captures.
          SizedBox(
            height: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown, // shrinks the row instead of overflowing
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final type in captured)
                      SvgPicture.asset(
                        'assets/pieces/$capturedColour${type.toUpperCase()}.svg',
                        width: 18,
                        height: 18,
                      ),
                    if (advantage > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          '+$advantage',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}