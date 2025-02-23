//util.dart
import 'package:stockfish/stockfish.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart' as squares;
import 'package:square_bishop/square_bishop.dart';

late bishop.Game game;
late SquaresState state;
int player = squares.Squares.white;
int engine = squares.Squares.black;
bool aiThinking = false;
bool flipBoard = false;
bool engineStarted = false;
String fen = '';
String bestMove = '';
String engineStatus = stockfish.state.value.toString();
String output = '';
//bool stockfishON=false;
int turn=-1;
late Stockfish stockfish;

