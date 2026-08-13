import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';

/// Navigation moves that do not depend on how a screen was reached.
extension CairnNavContext on BuildContext {
  /// Leaves the current screen, with or without history behind it.
  ///
  /// Tap a peak card and the detail screen has something to pop. Open the same
  /// location cold as a deep link and it has nothing, so a plain pop is a no-op
  /// and the screen becomes a dead end. That second case lands on the peaks list
  /// instead, which is where a visitor who typed a URL should end up.
  ///
  /// Every back control routes through here rather than deciding for itself, so
  /// a screen that gets rebuilt later keeps the behaviour by calling one method.
  void popOrHome() {
    if (canPop()) {
      pop();
    } else {
      go(CairnRoute.peaks);
    }
  }
}
