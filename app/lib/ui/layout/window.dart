import '../material.dart';

/// Material's window size classes, by available width.
enum WindowClass {
  /// Phones in portrait: under 600 dp.
  compact,

  /// Foldables, small tablets, phones in landscape: 600–839 dp.
  medium,

  /// Tablets, large foldables: 840 dp and up.
  expanded;

  static WindowClass of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);

  static WindowClass fromWidth(double width) => width < 600
      ? WindowClass.compact
      : width < 840
          ? WindowClass.medium
          : WindowClass.expanded;

  bool get isCompact => this == WindowClass.compact;
  bool get isExpanded => this == WindowClass.expanded;
}
