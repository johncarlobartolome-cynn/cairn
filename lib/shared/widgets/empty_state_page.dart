import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'cairn_back_button.dart';
import 'empty_state.dart';

/// A whole page whose only content is one [EmptyState].
///
/// The three misses in the app look the same, so they share this: a peak id with
/// no peak, a climb id with no climb, and a location the router cannot match.
///
/// The bar carries a [CairnBackButton], which works whether or not anything
/// pushed this page. The card's own action still names where it goes, since a
/// visitor who reached a miss cold is better served by a labelled way to the
/// peaks list than by an arrow.
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
      appBar: AppBar(leading: const CairnBackButton()),
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
