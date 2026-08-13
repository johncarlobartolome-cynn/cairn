import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/theme.dart';

/// The app widget: the two themes and the router, and nothing else.
///
/// Light is the design's default and dark is a full translation of it, so both
/// are wired and the phone's own setting picks.
class CairnApp extends StatefulWidget {
  const CairnApp({
    this.initialLocation = CairnRoute.peaks,
    this.themeMode = ThemeMode.system,
    super.key,
  });

  /// Where the router opens. Production takes the default; a test opens a screen
  /// directly to prove a deep link lands, the same seam `AppDatabase` gives its
  /// executor.
  final String initialLocation;

  /// Which of the two themes to draw. Production takes the default and follows
  /// the phone; the screenshot harness names a theme so one run captures both,
  /// and a test can assert a palette without touching device settings.
  final ThemeMode themeMode;

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
      themeMode: widget.themeMode,
      routerConfig: _router,
    );
  }
}
