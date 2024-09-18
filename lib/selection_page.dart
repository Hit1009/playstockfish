import 'package:flutter/material.dart';
import 'main.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart' as squares;
import 'package:square_bishop/square_bishop.dart';

class SelectionPage extends StatelessWidget {
  const SelectionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Side'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomePage(playerColor: squares.Squares.white),
                  ),
                );
              },
              child: const Text('Play as White'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomePage(playerColor: squares.Squares.black),
                  ),
                );

              },
              child: const Text('Play as Black'),

            ),
          ],
        ),
      ),
    );
  }
}