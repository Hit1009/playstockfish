import 'dart:math';

import 'package:flutter/material.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart' as squares;
import 'package:square_bishop/square_bishop.dart';
import 'package:stockfish/stockfish.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Play with stockfish',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late bishop.Game game;
  late SquaresState state;
  int player = squares.Squares.white;
  bool aiThinking = false;
  bool flipBoard = false;
  String fen='';
  String bestMove='';
  String engineStatus='';
  String output='';
  final stockfish = Stockfish();

  @override
  void initState() {
    _resetGame(false);
    super.initState();
  }

  void _resetGame([bool ss = true]) {
    game = bishop.Game(variant: bishop.Variant.standard());
    state = game.squaresState(player);
    if (ss) setState(() {});
  }

  void _flipBoard() => setState(() => flipBoard = !flipBoard);

  void _onMove(squares.Move move) async {
    bool result = game.makeSquaresMove(move);
    fen = game.fen;

    if (result) {
      setState(() => state = game.squaresState(player));
    }

    // Ask Stockfish for the best move if it's the engine's turn
    if (state.state == squares.PlayState.theirTurn && !aiThinking) {
      setState(() => aiThinking = true);

      stockfish.stdin='position fen $fen';
      stockfish.stdin='go movetime 2000';

      stockfish.stdout.listen((line) {
        if (line.startsWith('bestmove')) {
          bestMove = line.substring(9, 13);  // Extract the best move

          // Convert Stockfish move to a bishop Move object
          bishop.Move? aiMove = game.getMove(bestMove);

          if (aiMove != null) {
            game.makeMove(aiMove);  // Make the engine's move in the game
            setState(() {
              state = game.squaresState(player);
              aiThinking = false;
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('play with stockfish'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: squares.BoardController(
                state: flipBoard ? state.board.flipped() : state.board,
                playState: state.state,
                pieceSet: squares.PieceSet.merida(),
                theme: squares.BoardTheme.brown,
                moves: state.moves,
                onMove: _onMove,
                onPremove: _onMove,
                markerTheme: squares.MarkerTheme(
                  empty: squares.MarkerTheme.dot,
                  piece: squares.MarkerTheme.corners(),
                ),
                promotionBehaviour: squares.PromotionBehaviour.autoPremove,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: _resetGame,
              child: const Text('New Game'),
            ),
            Text(fen),
            Text("Black's bestMove: "+bestMove),
            IconButton(
              onPressed: _flipBoard,
              icon: const Icon(Icons.rotate_left),
            ),
          ],
        ),
      ),
    );
  }
}