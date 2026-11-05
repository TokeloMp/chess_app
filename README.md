# chess_app

A Flutter chess app for Android and iOS: pass-and-play or play the computer
(Easy or Normal). Built for a PBL module.

## Features
- Legal-move highlighting; check, checkmate, stalemate and draw detection
  (rules come from the `chess` package)
- Player cards with 10-minute clocks, move history, captured pieces
- Promotion dialog, Resign, Draw offer, New game
- Computer opponent: Easy (random) or Normal (two-move look-ahead)
- Responsive portrait and landscape layout

## Run it
Install Flutter, then run `flutter pub get` and `flutter run`.

## Structure
- `lib/`: main.dart, game_screen.dart, board_view.dart, player_card.dart,
  app_text.dart, chess_ai.dart
- `assets/pieces/`: SVG piece images. `assets/fonts/`: heading font

## Credits
- Piece images: "cburnett" set by Colin M.L. Burnett, via Lichess
  (listed there as GPLv2+)
- Font: DM Serif Display, SIL Open Font License 1.1
- Rules engine: the `chess` package on pub.dev
