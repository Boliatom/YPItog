import 'package:flutter/widgets.dart';

const compactWidth = 600.0;

const expandedWidth = 1024.0;

const maxContentWidth = 1440.0;

const maxFormWidth = 760.0;

enum ScreenSize {
  compact,

  medium,

  expanded;

  static ScreenSize of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  static ScreenSize forWidth(double width) {
    if (width < compactWidth) return ScreenSize.compact;
    if (width < expandedWidth) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  bool get isCompact => this == ScreenSize.compact;

  int get cardColumns => this == ScreenSize.medium ? 2 : 1;
}
