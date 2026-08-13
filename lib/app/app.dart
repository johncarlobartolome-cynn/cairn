import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/theme.dart';

/// The app widget: the two themes and the router, and nothing else.
///
/// Light is the design's default and dark is a full translation of it, so both
/// are wired and the phone's own setting picks.
class CairnApp extends StatefulWidget {
  const CairnApp({this.initialLocation = CairnRoute.peaks, super.key});

  /// Where the router opens. Production takes the default; a test opens a screen
  /// directly to prove a deep link lands, the same seam `AppDatabase` gives its
  /// executor.
  final String initialLocation;

  @override
  State<CairnApp> createState() => _CairnAppState();
}

class _CairnAppState extends State<CairnApp> {
  /// Built once. A `GoRouter` holds the navigation stack, so rebuilding one on
  /// every frame would throw the history away each time.
  late final GoRouter _router = createCairnRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cairn',
      debugShowCheckedModeBanner: false,
      theme: CairnTheme.light,
      darkTheme: CairnTheme.dark,
      routerConfig: _router,
    );
  }
}
