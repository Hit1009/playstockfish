import 'package:flutter/material.dart';
import 'selection_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

/// The main app widget.
class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Play with Stockfish",
      theme: ThemeData(primarySwatch: Colors.blue),
      
      home: const SelectionPage(),
    );
  }}
