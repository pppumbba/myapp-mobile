import 'package:flutter/material.dart';

import 'config.dart';

void main() {
  runApp(const WandApp());
}

class WandApp extends StatelessWidget {
  const WandApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.fromEnvironment();
    return MaterialApp(
      home: Scaffold(body: Center(child: Text('App ${config.appMetaId}'))),
    );
  }
}
