export 'slive_background_style.dart';
export 'slive_color_tokens.dart';
export 'slive_layout_tokens.dart';
export 'slive_material_tokens.dart';

import 'package:flutter/material.dart';

import 'slive_background_style.dart';
import 'slive_color_tokens.dart';
import 'slive_material_tokens.dart';

extension SliveThemeContext on BuildContext {
  SliveColorTokens get sliveColors {
    return Theme.of(this).extension<SliveColorTokens>() ??
        (Theme.of(this).brightness == Brightness.dark
            ? SliveColorTokens.dark(
                Theme.of(this).colorScheme.primary,
                background: const SliveBackgroundStyle().resolve(
                  Brightness.dark,
                ),
              )
            : SliveColorTokens.light(
                Theme.of(this).colorScheme.primary,
                background: const SliveBackgroundStyle().resolve(
                  Brightness.light,
                ),
              ));
  }

  SliveMaterialTokens get sliveMaterials {
    return Theme.of(this).extension<SliveMaterialTokens>() ??
        SliveMaterialTokens.resolve(
          SliveGlassMode.soft,
          Theme.of(this).brightness,
        );
  }
}
