import 'package:flutter/widgets.dart';

/// Exposes which shell tab is currently active so each branch can mute its
/// animations when it is NOT the visible tab. The StatefulShellRoute keeps
/// every branch alive (IndexedStack), so [TickerMode] must be applied
/// per-screen against this value — otherwise the genre constellation, hero
/// rotation and shimmer burn frames in background tabs.
class ActiveBranchScope extends InheritedWidget {
  final int index;

  const ActiveBranchScope({
    super.key,
    required this.index,
    required super.child,
  });

  static ActiveBranchScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ActiveBranchScope>();

  bool isActive(int branchIndex) => branchIndex == index;

  @override
  bool updateShouldNotify(ActiveBranchScope oldWidget) =>
      oldWidget.index != index;
}
