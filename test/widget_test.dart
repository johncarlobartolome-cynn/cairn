import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:cairn/main.dart';

void main() {
  testWidgets('app boots inside a ProviderScope', (tester) async {
    await tester.pumpWidget(const CairnApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
