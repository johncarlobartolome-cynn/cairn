import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';

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
      home: const Scaffold(body: SafeArea(child: _SeededPeaksList())),
    );
  }
}

// Throwaway: proves seeded rows reach the UI through a provider. T9 replaces the
// styling and E2 replaces this screen with the real mountain library.
class _SeededPeaksList extends ConsumerWidget {
  const _SeededPeaksList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peaks = ref.watch(mountainsProvider);

    return switch (peaks) {
      AsyncValue(hasError: true, :final error) => Center(child: Text('$error')),
      AsyncValue(hasValue: true, :final value?) => ListView(
        children: [for (final peak in value) ListTile(title: Text(peak.name))],
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
