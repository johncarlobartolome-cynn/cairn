import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/providers.dart';

void main() {
  // The photo pass below looks the documents directory up through
  // path_provider, which is a platform channel, so the binding has to be up
  // before anything reads it.
  WidgetsFlutterBinding.ensureInitialized();

  final ProviderContainer container = ProviderContainer();

  // Photos taken before T24's cap existed are brought inside it once, here,
  // rather than on the screen that draws them. Started and not awaited: it
  // rewrites files under the names they already have, so a screen that reads
  // one mid-pass gets either the old photo or the new one and draws the same
  // picture either way. Nothing about it should hold the first frame.
  container.read(photoCapPassProvider);

  runApp(
    UncontrolledProviderScope(container: container, child: const CairnApp()),
  );
}
