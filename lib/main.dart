import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: CairnApp()));
}

class CairnApp extends StatelessWidget {
  const CairnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cairn',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(
        body: SafeArea(child: SizedBox.expand()),
      ),
    );
  }
}
