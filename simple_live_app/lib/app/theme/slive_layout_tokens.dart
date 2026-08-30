import 'package:flutter/material.dart';

abstract final class SliveRadii {
  static const double control = 16;
  static const double cover = 17;
  static const double card = 22;
  static const double panel = 26;
  static const double player = 24;
  static const double dock = 34;
  static const double pill = 999;
}

abstract final class SliveMotion {
  static const Duration press = Duration(milliseconds: 90);
  static const Duration selection = Duration(milliseconds: 180);
  static const Duration panel = Duration(milliseconds: 220);
  static const Duration route = Duration(milliseconds: 200);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
}

abstract final class SliveLayout {
  static const double pageHorizontal = 12;
  static const double gridGap = 12;
  static const double bottomDockHeight = 66;
  static const double bottomDockGap = 22;
  static const double minimumTouchTarget = 44;
}
