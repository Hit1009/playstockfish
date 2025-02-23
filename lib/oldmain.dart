import 'package:flutter/material.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart' as squares;
import 'package:square_bishop/square_bishop.dart';
import 'package:stockfish/stockfish.dart';
import 'selection_page.dart';
import 'util.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Play with Stockfish',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SelectionPage(), // Start with the selection page
    );
  }
}

class HomePage extends StatefulWidget {
  final int playerColor; // Add player color selection
  const HomePage({Key? key, required this.playerColor}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    stockfish = Stockfish();
    player = widget.playerColor;
    engine =
    player == squares.Squares.white ? squares.Squares.black : squares.Squares
        .white;
    engineStarted = false;
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
    if (engineStarted) {
      bool result = game.makeSquaresMove(move);
      fen = game.fen;

      if (result) {
        setState(() => state = game.squaresState(player));
      }

      // Ask Stockfish for the best move if it's the engine's turn
      if (state.state == squares.PlayState.theirTurn && !aiThinking) {
        setState(() => aiThinking = true);
        makeStockfishMove();
      }
      turn = turn == 0 ? 1 : 0;
    }
  }

  void startEngine() {
    if (!engineStarted) {
      stockfish.stdin = 'isready';
      stockfish.stdout.listen((line) {
        engineStatus = line;
      });
      if (engineStatus == 'readyok') {
        setState(() {
          engineStarted = true;
          if (engine == squares.Squares.white && engineStarted && turn == 0) {
            stockfishMoveController();
            turn = 1;
          }
        });
      }
    }
  }

  void stockfishMoveController() {
    setState(() {
      fen=game.fen;
      game.squaresState(engine);
      makeStockfishMove();
    });
  }

  void makeStockfishMove() {
    stockfish.stdin = 'position fen $fen';
    stockfish.stdin = 'go movetime 100';

    stockfish.stdout.listen((line) {
      if (line.startsWith('bestmove')) {
        bestMove = line.substring(9, 13); // Extract the best move
        // Convert Stockfish move to a bishop Move object
        bishop.Move? aiMove = game.getMove(bestMove);
        if (aiMove != null) {
          game.makeMove(aiMove); // Make the engine's move in the game
          setState(() {
            state = game.squaresState(player);
            aiThinking = false;
          });
        }
      }
    });
  }

  void toggleEngine() {
    setState(() {
      engineStarted = !engineStarted;
      engineStatus = engineStarted ? 'Engine Running' : 'Engine Stopped';
    });
  }

  void _navigateToSelectionPage() {
    stockfish.dispose();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SelectionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play with Stockfish'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(stockfish.toString()),
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
              onPressed: () {
                //stockfish.dispose();
                _navigateToSelectionPage();
              }, // Navigate to selection page
              child: const Text('New Game'),
            ),
            Text(fen),
            Text("Engine status: " + engineStarted.toString()),
            IconButton(
              onPressed: _flipBoard,
              icon: const Icon(Icons.rotate_left),
            ),
            OutlinedButton(
              onPressed: startEngine, // Play/Stop button
              child: Text('start engine'),
            ),
          ],
        ),
      ),
    );
  }
}