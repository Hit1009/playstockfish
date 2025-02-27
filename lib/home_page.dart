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
  List<String> moveHistory = [];
  List<String> algebraicMoveHistory = [];
  int currentMoveIndex = -1;

  bool aiThinking = false;
  bool engineStarted = true; // Engine is running by default.
  String engineStatus = "Engine Running";
  // Engine color is opposite of the player's color.
  late int engine;

  @override
  void initState() {
    super.initState();

    // Initialize the game.
    game = bishop.Game(variant: bishop.Variant.standard());
    currentState = game.squaresState(widget.playerColor);
    moveHistory.add(game.fen);
    currentMoveIndex = 0;

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
        if (parts.isNotEmpty && parts.length >= 2) {
          String bestMoveStr = parts[1];
          bishop.Move? aiMove = game.getMove(bestMoveStr);
          if (aiMove != null) {
            // Add the move in algebraic notation
            String algebraicMove = game.toSan(aiMove);
            game.makeMove(aiMove);
            setState(() {
              currentState = game.squaresState(widget.playerColor);
              aiThinking = false;
              // Update move history for engine moves
              if (currentMoveIndex < moveHistory.length - 1) {
                moveHistory = moveHistory.sublist(0, currentMoveIndex + 1);
                algebraicMoveHistory = algebraicMoveHistory.sublist(0, currentMoveIndex + 1);
              }
              moveHistory.add(game.fen);
              algebraicMoveHistory.add(algebraicMove);
              currentMoveIndex = moveHistory.length - 1;
            });
            
            // Check for game ending conditions after engine move
            if (currentState.state == squares.PlayState.finished) {
              checkGameEndingCondition();
            }
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
  // Handle a move made on the chessboard.
  void onMove(squares.Move move) {
    bool result = game.makeSquaresMove(move);
    if (result) {
      // Get the last move in algebraic notation
      String algebraicMove = "";
      if (game.history.isNotEmpty && game.history.last.meta?.moveMeta != null) {
        algebraicMove = game.history.last.meta!.moveMeta!.formatted;
      }
      
      setState(() {
        currentState = game.squaresState(widget.playerColor);
        if (currentMoveIndex < moveHistory.length - 1) {
          moveHistory = moveHistory.sublist(0, currentMoveIndex + 1);
          algebraicMoveHistory = algebraicMoveHistory.sublist(0, currentMoveIndex + 1);
        }
        moveHistory.add(game.fen);
        algebraicMoveHistory.add(algebraicMove);
        currentMoveIndex++;
      });
      
      // Check for game ending conditions
      if (currentState.state == squares.PlayState.finished) {
        checkGameEndingCondition();
      } else if (engineStarted &&
          currentState.state == squares.PlayState.theirTurn &&
          !aiThinking) {
        setState(() {
          aiThinking = true;
        });
        makeStockfishMove();
      }
    }
  }
  void undoMove() {
    // Undo both player and engine moves together
    if (currentMoveIndex > 1) {
      setState(() {
        currentMoveIndex -= 2; // Go back two moves
        game = bishop.Game(fen: moveHistory[currentMoveIndex]);
        currentState = game.squaresState(widget.playerColor);
      });
    } else if (currentMoveIndex > 0) { // Handle the case when only one move is available
      setState(() {
        currentMoveIndex--;
        game = bishop.Game(fen: moveHistory[currentMoveIndex]);
        currentState = game.squaresState(widget.playerColor);
      });
    }
  }
  void redoMove() {
    if (currentMoveIndex < moveHistory.length - 1) {
      setState(() {
        currentMoveIndex++;
        game = bishop.Game(fen: moveHistory[currentMoveIndex]);
        currentState = game.squaresState(widget.playerColor);
      });
    }
  }
  // Send commands to Stockfish.
  void makeStockfishMove() {
    if (!engineStarted) return;
    stockfish.stdin = 'position fen ${game.fen}';
    stockfish.stdin = 'go movetime 100';
  }
  // Toggle the engine on and off.
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
  
  // Check game ending condition and show appropriate dialog
  void checkGameEndingCondition() {
    String title = "Game Over";
    String message = "";
    
    if (game.checkmate) {
      // Determine who won based on whose turn it is
      bool whiteWon = game.turn == 1; // In bishop, turn 0 is white, 1 is black
      String winner = whiteWon ? "Black" : "White";
      message = "$winner wins by checkmate!";
    } else if (game.stalemate) {
      message = "Game drawn by stalemate.";
    } else if (game.insufficientMaterial) {
      message = "Game drawn by insufficient material.";
    } 
     else {
      message = "Game ended.";
    }
    
    // Show dialog after a short delay to ensure UI is updated
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.blueGrey.shade900,
              title: Text(title, style: const TextStyle(color: Colors.white)),
              content: Text(message, style: const TextStyle(color: Colors.white)),
              actions: [
                TextButton(
                  child: const Text("New Game", style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    navigateToSelectionPage();
                  },
                ),
                TextButton(
                  child: const Text("Close", style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
              // Chessboard area inside a container with subtle styling
              Expanded(
                child: Center(
                  child: GlassMorphismContainer(
                    child: squares.BoardController(
                      state: currentState.board,
                      playState: currentState.state,
                      pieceSet: squares.PieceSet.merida(),
                      theme: squares.BoardTheme.brown,
                      moves: currentState.moves,
                      onMove: onMove,
                      promotionBehaviour: squares.PromotionBehaviour.autoPremove,
                    ),
                  ),
                ),
              ),
              // Move history display
              Container(
                height: 100,
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: algebraicMoveHistory.isEmpty
                    ? const Center(
                        child: Text(
                          "No moves yet",
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: algebraicMoveHistory.length,
                        itemBuilder: (context, index) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: index == currentMoveIndex
                                  ? Colors.blueAccent.withOpacity(0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Center(
                              child: Text(
                                "${(index ~/ 2) + 1}${index % 2 == 0 ? '.' : '...'} ${algebraicMoveHistory[index]}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: index == currentMoveIndex
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              
              // Game status and controls
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text("Engine status: $engineStatus",
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 16),
                    // Undo/Redo controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: undoMove,
                          icon: const Icon(Icons.arrow_back),
                          color: Colors.white,
                          tooltip: 'Undo move',
                        ),
                        const SizedBox(width: 32),
                        IconButton(
                          onPressed: redoMove,
                          icon: const Icon(Icons.arrow_forward),
                          color: Colors.white,
                          tooltip: 'Redo move',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (aiThinking) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A container widget with a simple, elegant styling.
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}