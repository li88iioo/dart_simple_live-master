import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';

class AppLoaddingWidget extends StatefulWidget {
  const AppLoaddingWidget({super.key});

  @override
  State<AppLoaddingWidget> createState() => _AppLoaddingWidgetState();
}

class _AppLoaddingWidgetState extends State<AppLoaddingWidget> {
  Timer? _delay;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _delay = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Center(
      child: SizedBox.square(
        dimension: 48,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: reduceMotion ? Duration.zero : SliveMotion.press,
          child: SliveGlassSurface(
            variant: SliveGlassVariant.pill,
            radius: SliveRadii.pill,
            enableBackdropBlur: false,
            child: const Center(
              child: CupertinoActivityIndicator(radius: 10),
            ),
          ),
        ),
      ),
    );
  }
}
