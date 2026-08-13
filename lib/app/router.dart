import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/badges/badges_screen.dart';
import '../features/climbs/climb_detail_screen.dart';
import '../features/peaks/peak_detail_screen.dart';
import '../features/peaks/peaks_screen.dart';
import '../shared/widgets/empty_state_page.dart';
import 'nav_shell.dart';

/// Every location in the app.
///
/// Screens build a location by calling [mountain] or [climb] rather than writing
/// the string, so a path lives in one place and a typo cannot compile.
abstract final class CairnRoute {
  /// The peaks list, and the app's start location.
  static const String peaks = '/';

  static const String badges = '/badges';

  /// Pattern form, for the router only. Call [mountain] for a real location.
  static const String mountainPattern = '/mountain/:$idParam';

  /// Pattern form, for the router only. Call [climb] for a real location.
  static const String climbPattern = '/climb/:$idParam';

  static const String idParam = 'id';

  static String mountain(int id) => '/mountain/$id';

  static String climb(int id) => '/climb/$id';
}

/// Builds the app's router.
///
/// A factory, not a top-level constant: a `GoRouter` owns a navigation stack, so
/// a single shared instance would carry one test's history into the next.
///
/// `/` and `/badges` are the two nav destinations, so they sit inside a
/// [StatefulShellRoute.indexedStack]. Each keeps its own scroll offset and
/// history, and the floating nav stays put while you swap between them. The two
/// id routes are declared as siblings of the shell rather than inside it, which
/// is what makes them push over it as full pages with no nav.
GoRouter createCairnRouter({String initialLocation = CairnRoute.peaks}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => NavShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: CairnRoute.peaks,
                builder: (context, state) => const PeaksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: CairnRoute.badges,
                builder: (context, state) => const BadgesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: CairnRoute.mountainPattern,
        builder: (context, state) => PeakDetailScreen(mountainId: _id(state)),
      ),
      GoRoute(
        path: CairnRoute.climbPattern,
        builder: (context, state) => ClimbDetailScreen(climbId: _id(state)),
      ),
    ],
    // A location that matches nothing lands here instead of on a red screen.
    errorBuilder: (context, state) => EmptyStatePage(
      icon: Icons.explore_off_rounded,
      title: 'Nothing here',
      message: 'That link does not lead anywhere in Cairn.',
      action: FilledButton(
        onPressed: () => context.go(CairnRoute.peaks),
        child: const Text('Back to peaks'),
      ),
    ),
  );
}

/// The `:id` segment as an int, or null when it is not a number.
///
/// `/mountain/abc` misses for the same reason `/mountain/999` does, and both
/// end on the same not-found screen, so a failed parse travels as a null rather
/// than throwing on the way to the widget.
int? _id(GoRouterState state) =>
    int.tryParse(state.pathParameters[CairnRoute.idParam] ?? '');
