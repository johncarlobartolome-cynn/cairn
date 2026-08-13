import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'empty_state.dart';

/// A whole page whose only content is one [EmptyState].
///
/// The three misses in the app look the same, so they share this: a peak id with
/// no peak, a climb id with no climb, and a location the router cannot match.
///
/// The bar carries the back arrow when there is something to go back to. Arrive
/// here from a cold deep link and there is nothing to pop, which is why the
/// caller can hand the card an action instead.
class EmptyStatePage extends StatelessWidget {
  const EmptyStatePage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CairnSpace.page),
            child: EmptyState(
              icon: icon,
              title: title,
              message: message,
              action: action,
            ),
          ),
        ),
      ),
    );
  }
}
