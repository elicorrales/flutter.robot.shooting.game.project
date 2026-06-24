// main.dart
// Entry point. Initializes shared_preferences before the first frame, then runs
// the game. (Window sizing/title can be added with the `window_manager` package
// if you want a fixed initial window; left out to keep native deps minimal.)

import 'package:flutter/material.dart';
import 'robot.game.storage.dart';
import 'robot.game.ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();
  runApp(const RobotGameApp());
}

class RobotGameApp extends StatelessWidget {
  const RobotGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Shooting Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const GameScreen(),
    );
  }
}
