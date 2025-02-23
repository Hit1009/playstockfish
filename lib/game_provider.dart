// game_provider.dart
import 'package:flutter/material.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';
import 'package:stockfish/stockfish.dart';

class GameProvider extends ChangeNotifier {
  late bishop.Game game;
  final Stockfish stockfish = Stockfish();
  StreamSubscription<String>? _stockfishSubscription;

  bool _aiThinking = false;
  bool _engineStarted = true;
  String _errorMessage = '';
  List<String> _moveHistory = [];
  int _playerColor = Squares.white;
  bool _gameOver = false;

  SquaresState get currentState => game.squaresState(_playerColor);
  bool get aiThinking => _aiThinking;
  bool get engineStarted => _engineStarted;
  String get errorMessage => _errorMessage;
  List<String> get moveHistory => _moveHistory;
  bool get gameOver => _gameOver;

  GameProvider() {
    _initGame();
    _initStockfish();
  }

  void _initGame() {
    game = bishop.Game(variant: bishop.Variant.standard());
    _moveHistory = [];
    _gameOver = false;
    notifyListeners();
  }

  void _initStockfish() {
    _stockfishSubscription = stockfish.stdout.listen(_handleStockfishOutput);
  }

  void _handleStockfishOutput(String line) {
    if (line.startsWith("bestmove") && _aiThinking) {
      final parts = line.split(' ');
      if (parts.length > 1) {
        final move = parts[1];
        _makeAIMove(move);
      }
      _aiThinking = false;
      notifyListeners();
    }
  }

  void _makeAIMove(String moveStr) {
    try {
      final move = game.getMove(moveStr);
      if (move != null && game.validateMove(move)) {
        game.makeMove(move);
        _moveHistory.add(move.uci());
        _checkGameStatus();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to parse AI move: $e';
      notifyListeners();
    }
  }

  void _checkGameStatus() {
    _gameOver = game.gameOver;
    notifyListeners();
  }

  void makeMove(squares.Move move) {
    if (_gameOver) return;

    try {
      final bishopMove = game.moveFromSquares(
        move.from,
        move.to,
        promotion: move.promotion,
      );

      if (bishopMove != null && game.validateMove(bishopMove)) {
        game.makeMove(bishopMove);
        _moveHistory.add(bishopMove.uci());
        _checkGameStatus();
        notifyListeners();

        if (engineStarted && !_gameOver && currentState.state == PlayState.theirTurn) {
          _aiThinking = true;
          _sendToStockfish();
          notifyListeners();
        }
      }
    } catch (e) {
      _errorMessage = 'Invalid move: ${e.toString()}';
      notifyListeners();
    }
  }

  void _sendToStockfish() {
    stockfish.stdin = 'position fen ${game.fen}';
    stockfish.stdin = 'go movetime 100';
  }

  void toggleEngine() {
    _engineStarted = !_engineStarted;
    notifyListeners();
    if (_engineStarted && currentState.state == PlayState.theirTurn) {
      _aiThinking = true;
      _sendToStockfish();
      notifyListeners();
    }
  }

  void newGame(int playerColor) {
    _playerColor = playerColor;
    _initGame();
    if (_engineStarted && playerColor == Squares.black) {
      _aiThinking = true;
      _sendToStockfish();
    }
    notifyListeners();
  }

  String get gameStatus {
    if (game.gameOver) {
      final outcome = game.outcome;
      if (outcome?.result == bishop.Result.checkmate) {
        return 'Checkmate! ${outcome?.winner == bishop.Color.white ? "White" : "Black"} wins!';
      }
      if (outcome?.result == bishop.Result.stalemate) return 'Stalemate!';
      if (outcome?.result == bishop.Result.draw) return 'Draw!';
      return 'Game Over!';
    }
    if (aiThinking) return 'Stockfish is thinking...';
    return currentState.state == PlayState.theirTurn
        ? 'Engine\'s turn'
        : 'Your turn';
  }

  @override
  void dispose() {
    _stockfishSubscription?.cancel();
    stockfish.dispose();
    super.dispose();
  }
}