import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/pill_nav.dart';

/// Holds the two nav destinations and the floating nav that swaps them.
///
/// The nav floats over the branch content in a [Stack] rather than sitting in
/// `bottomNavigationBar`, because the design has it hovering with the ground
/// showing through on either side.
///
/// One [Scaffold] and one [SafeArea] serve both branches, and that single
/// [SafeArea] matters more than it looks. A screen inside it reads a zeroed
/// bottom inset, and so does the nav, so [PillNav.clearanceFor] hands the same
/// number to both and the gesture inset is never counted twice. A screen that
/// nests its own [SafeArea] is harmless: the inset is already spent.
class NavShell extends StatelessWidget {
  const NavShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            shell,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PillNav(
                currentIndex: shell.currentIndex,
                // goBranch keeps each branch's own history. Tapping the
                // destination you are already on resets that branch to its root,
                // which is the usual way out of a stack you navigated into.
                onSelected: (index) => shell.goBranch(
                  index,
                  initialLocation: index == shell.currentIndex,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
