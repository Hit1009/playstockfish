import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart' as squares;
import 'package:square_bishop/square_bishop.dart';
import 'package:stockfish/stockfish.dart';
import 'selection_page.dart';

/// The home page which displays the chessboard and game controls.
class HomePage extends StatefulWidget {
  final int playerColor;
  const HomePage({Key? key, required this.playerColor}) : super(key: key);

  @override
  State<HomePage> createState() => HomePageState();
}

/// The state holding game interactions and UI updates.
class HomePageState extends State<HomePage> {
  late bishop.Game game;
  late var currentState;
  late Stockfish stockfish;
  StreamSubscription<String>? stockfishSubscription;

  bool aiThinking = false;
  bool engineStarted = true; // Engine is running by default.
  String engineStatus = "Engine Running";
  // Engine color is opposite of the player's color.
  late int engine;

  // To display move history.
  List<String> moveHistory = [];

  @override
  void initState() {
    super.initState();

    // Initialize the game.
    game = bishop.Game(variant: bishop.Variant.standard());
    currentState = game.squaresState(widget.playerColor);

    // Initialize Stockfish.
    stockfish = Stockfish();

    // Set the engine color to the opposite of the player's color.
    engine = widget.playerColor == squares.Squares.white
        ? squares.Squares.black
        : squares.Squares.white;

    // Listen to Stockfish output.
    stockfishSubscription = stockfish.stdout.listen((String line) {
      if (line.startsWith("bestmove") && aiThinking) {
        final parts = line.split(' ');
        if (parts.isNotEmpty) {
          String bestMoveStr = parts[1];
          bishop.Move? aiMove = game.getMove(bestMoveStr);
          if (aiMove != null) {
            game.makeMove(aiMove);
            moveHistory.add(bestMoveStr);
            setState(() {
              currentState = game.squaresState(widget.playerColor);
              aiThinking = false;
            });
          }
        }
      }
    });

    // If the engine is started and it's the engine's turn (e.g. when playing as Black),
    // trigger the engine move after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (engineStarted &&
          currentState.state == squares.PlayState.theirTurn &&
          !aiThinking) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && engineStarted && !aiThinking) {
            setState(() {
              aiThinking = true;
            });
            makeStockfishMove();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    stockfishSubscription?.cancel();
    stockfish.dispose();
    super.dispose();
  }

  // Navigate to selection page.
  void navigateToSelectionPage() {
    stockfish.dispose();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SelectionPage()),
    );
  }

  void onMove(squares.Move move) {
    bool result = game.makeSquaresMove(move);
    if (result) {
      moveHistory.add(move.toString());
      setState(() {
        currentState = game.squaresState(widget.playerColor);
      });
      if (engineStarted &&
          currentState.state == squares.PlayState.theirTurn &&
          !aiThinking) {
        setState(() {
          aiThinking = true;
        });
        makeStockfishMove();
      }
    }
  }

  void makeStockfishMove() {
    if (!engineStarted) return;
    stockfish.stdin = 'position fen ${game.fen}';
    stockfish.stdin = 'go movetime 100';
  }

  void toggleEngine() {
    setState(() {
      engineStarted = !engineStarted;
      engineStatus = engineStarted ? "Engine Running" : "Engine Stopped";
    });
    if (engineStarted &&
        currentState.state == squares.PlayState.theirTurn &&
        !aiThinking) {
      setState(() {
        aiThinking = true;
      });
      makeStockfishMove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Radial gradient background.
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [Colors.blueGrey.shade800, Colors.black],
            center: const Alignment(0.0, -0.5),
            radius: 1.5,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top control panel.
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // "New Game" button now navigates back to selection page.
                    OutlinedButton(
                      onPressed: navigateToSelectionPage,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: const Text(
                        "New Game",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    // Engine toggle button.
                    OutlinedButton(
                      onPressed: toggleEngine,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: Text(
                        engineStarted ? "Stop Engine" : "Start Engine",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              // Chessboard area inside a glassmorphism container.
              Expanded(
                child: Center(
                  child: GlassMorphismContainer(
                    child: squares.BoardController(
                      // Use the board state without flipping.
                      state: currentState.board,
                      playState: currentState.state,
                      pieceSet: squares.PieceSet.merida(),
                      theme: squares.BoardTheme.brown,
                      moves: currentState.moves,
                      onMove: onMove,
                      promotionBehaviour:
                      squares.PromotionBehaviour.autoPremove,
                    ),
                  ),
                ),
              ),
              // Game status and move history.
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text("FEN: ${game.fen}",
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text("Engine status: $engineStatus",
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            moveHistory.join(" "),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A container widget that applies a glassmorphism effect.
class GlassMorphismContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  const GlassMorphismContainer({
    Key? key,
    required this.child,
    this.borderRadius = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
