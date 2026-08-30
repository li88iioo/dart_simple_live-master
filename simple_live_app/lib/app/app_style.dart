import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';

class AppColors {
  static ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff3498db),
    brightness: Brightness.light,
  );
  static ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff3498db),
    brightness: Brightness.dark,
  );

  static const Color black333 = Color(0xFF333333);
}

class AppStyle {
  static ThemeData light({
    String? fontFamily,
    ColorScheme? colorScheme,
    SliveGlassMode glassMode = SliveGlassMode.soft,
    SliveBackgroundStyle backgroundStyle = const SliveBackgroundStyle(),
    Color? dynamicBackgroundSurface,
    SliveBackgroundPalette? backgroundPalette,
  }) {
    return _buildTheme(
      brightness: Brightness.light,
      sourceScheme: colorScheme ?? AppColors.lightColorScheme,
      fontFamily: fontFamily,
      glassMode: glassMode,
      backgroundStyle: backgroundStyle,
      dynamicBackgroundSurface: dynamicBackgroundSurface,
      backgroundPalette: backgroundPalette,
    );
  }

  static ThemeData darkTheme({
    String? fontFamily,
    ColorScheme? colorScheme,
    SliveGlassMode glassMode = SliveGlassMode.soft,
    SliveBackgroundStyle backgroundStyle = const SliveBackgroundStyle(),
    Color? dynamicBackgroundSurface,
    SliveBackgroundPalette? backgroundPalette,
  }) {
    return _buildTheme(
      brightness: Brightness.dark,
      sourceScheme: colorScheme ?? AppColors.darkColorScheme,
      fontFamily: fontFamily,
      glassMode: glassMode,
      backgroundStyle: backgroundStyle,
      dynamicBackgroundSurface: dynamicBackgroundSurface,
      backgroundPalette: backgroundPalette,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme sourceScheme,
    required String? fontFamily,
    required SliveGlassMode glassMode,
    required SliveBackgroundStyle backgroundStyle,
    required Color? dynamicBackgroundSurface,
    required SliveBackgroundPalette? backgroundPalette,
  }) {
    final isDark = brightness == Brightness.dark;
    final background = backgroundPalette ??
        backgroundStyle.resolve(
          brightness,
          dynamicSurface: dynamicBackgroundSurface,
        );
    final colors = isDark
        ? SliveColorTokens.dark(
            sourceScheme.primary,
            background: background,
          )
        : SliveColorTokens.light(
            sourceScheme.primary,
            background: background,
          );
    final materials = SliveMaterialTokens.resolve(glassMode, brightness);
    final scheme = sourceScheme.copyWith(
      brightness: brightness,
      surface: colors.backgroundBase,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      surfaceContainerLowest: colors.backgroundStart,
      surfaceContainerLow: Color.lerp(
        colors.backgroundBase,
        colors.glassBase,
        isDark ? 0.08 : 0.36,
      ),
      surfaceContainer: Color.lerp(
        colors.backgroundBase,
        colors.glassBase,
        isDark ? 0.12 : 0.52,
      ),
      surfaceContainerHigh: Color.lerp(
        colors.backgroundBase,
        colors.glassStrong,
        isDark ? 0.18 : 0.66,
      ),
      surfaceContainerHighest: Color.lerp(
        colors.backgroundBase,
        colors.glassStrong,
        isDark ? 0.24 : 0.78,
      ),
      outline: colors.textTertiary.withValues(alpha: isDark ? 0.50 : 0.58),
      outlineVariant: colors.divider.withValues(alpha: isDark ? 0.18 : 0.12),
      error: colors.danger,
    );
    final interactionOverlay = WidgetStateProperty.resolveWith<Color?>(
      (states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        if (states.contains(WidgetState.pressed)) {
          return scheme.primary.withValues(alpha: isDark ? 0.10 : 0.072);
        }
        if (states.contains(WidgetState.focused)) {
          return scheme.primary.withValues(alpha: isDark ? 0.075 : 0.048);
        }
        if (states.contains(WidgetState.hovered)) {
          return scheme.primary.withValues(alpha: isDark ? 0.055 : 0.034);
        }
        return Colors.transparent;
      },
    );
    final flatInteractionStyle = ButtonStyle(
      overlayColor: interactionOverlay,
      splashFactory: NoSplash.splashFactory,
      elevation: const WidgetStatePropertyAll<double>(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    );
    final baseTextTheme =
        (isDark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
              fontFamily: fontFamily,
              bodyColor: colors.textPrimary,
              displayColor: colors.textPrimary,
            );
    final textTheme = baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.18,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        color: colors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: colors.textSecondary,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: colors.textTertiary,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        color: colors.textTertiary,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: scheme.primary.withValues(
        alpha: isDark ? 0.085 : 0.064,
      ),
      hoverColor: scheme.primary.withValues(alpha: isDark ? 0.055 : 0.034),
      focusColor: scheme.primary.withValues(alpha: isDark ? 0.075 : 0.048),
      shadowColor: Colors.transparent,
      applyElevationOverlayColor: false,
      fontFamily: fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: colors.backgroundBase,
      canvasColor: colors.backgroundBase,
      cardColor: colors.glassBase.withValues(alpha: materials.cardOpacity),
      cardTheme: CardThemeData(
        color: colors.glassBase.withValues(alpha: materials.cardOpacity),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SliveRadii.card),
          side: BorderSide(
            color: colors.glassBorder.withValues(
              alpha: materials.borderOpacity * (isDark ? 0.62 : 0.82),
            ),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.glassStrong.withValues(alpha: 0.94),
        modalBackgroundColor: colors.glassStrong.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.42 : 0.20),
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: colors.textTertiary.withValues(alpha: 0.42),
        dragHandleSize: const Size(38, 4),
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(maxWidth: 720),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SliveRadii.panel),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.glassStrong.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        barrierColor: Colors.black.withValues(alpha: isDark ? 0.44 : 0.22),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SliveRadii.panel),
          side: BorderSide(
            color: colors.glassBorder.withValues(
              alpha: materials.borderOpacity * (isDark ? 0.58 : 0.80),
            ),
          ),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.glassStrong.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SliveRadii.control),
          side: BorderSide(
            color: colors.glassBorder.withValues(
              alpha: materials.borderOpacity * (isDark ? 0.56 : 0.78),
            ),
          ),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.10),
          isDark ? const Color(0xEE302B27) : const Color(0xEE2B2623),
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFFFFBF6),
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SliveRadii.pill),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.textPrimary.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(SliveRadii.pill),
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: isDark ? const Color(0xFF2B2623) : const Color(0xFFFFFBF6),
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: colors.divider.withValues(alpha: isDark ? 0.16 : 0.10),
      iconButtonTheme: IconButtonThemeData(style: flatInteractionStyle),
      textButtonTheme: TextButtonThemeData(style: flatInteractionStyle),
      filledButtonTheme: FilledButtonThemeData(style: flatInteractionStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: flatInteractionStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: flatInteractionStyle),
      radioTheme: RadioThemeData(overlayColor: interactionOverlay),
      checkboxTheme: CheckboxThemeData(overlayColor: interactionOverlay),
      switchTheme: SwitchThemeData(overlayColor: interactionOverlay),
      sliderTheme: SliderThemeData(
        overlayColor: scheme.primary.withValues(alpha: isDark ? 0.10 : 0.075),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        overlayColor: interactionOverlay,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: colors.textPrimary,
          fontSize: 17,
        ),
        foregroundColor: colors.textPrimary,
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: colors.textSecondary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicatorColor: scheme.primary,
        overlayColor: interactionOverlay,
        splashFactory: NoSplash.splashFactory,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider.withValues(alpha: isDark ? 0.16 : 0.10),
        thickness: 0.5,
        space: 0.5,
        indent: 16,
        endIndent: 16,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        subtitleTextStyle: textTheme.bodySmall,
        minVerticalPadding: 10,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.glassBase.withValues(
          alpha: isDark ? 0.34 : 0.58,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SliveRadii.control),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SliveRadii.control),
          borderSide: BorderSide(
            color: colors.glassBorder.withValues(
              alpha: materials.borderOpacity * (isDark ? 0.62 : 0.72),
            ),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SliveRadii.control),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.58),
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        colors,
        materials,
      ],
    );
  }

  static const vGap4 = SizedBox(
    height: 4,
  );
  static const vGap8 = SizedBox(
    height: 8,
  );
  static const vGap12 = SizedBox(
    height: 12,
  );
  static const vGap24 = SizedBox(
    height: 24,
  );
  static const vGap32 = SizedBox(
    height: 32,
  );
  static const vGap48 = SizedBox(
    height: 48,
  );

  static const hGap4 = SizedBox(
    width: 4,
  );
  static const hGap8 = SizedBox(
    width: 8,
  );
  static const hGap12 = SizedBox(
    width: 12,
  );
  static const hGap16 = SizedBox(
    width: 16,
  );

  static const hGap24 = SizedBox(
    width: 24,
  );
  static const hGap32 = SizedBox(
    width: 32,
  );
  static const hGap48 = SizedBox(
    width: 48,
  );

  static const edgeInsetsH4 = EdgeInsets.symmetric(horizontal: 4);
  static const edgeInsetsH8 = EdgeInsets.symmetric(horizontal: 8);
  static const edgeInsetsH12 = EdgeInsets.symmetric(horizontal: 12);
  static const edgeInsetsH16 = EdgeInsets.symmetric(horizontal: 16);
  static const edgeInsetsH20 = EdgeInsets.symmetric(horizontal: 20);
  static const edgeInsetsH24 = EdgeInsets.symmetric(horizontal: 24);

  static const edgeInsetsV4 = EdgeInsets.symmetric(vertical: 4);
  static const edgeInsetsV8 = EdgeInsets.symmetric(vertical: 8);
  static const edgeInsetsV12 = EdgeInsets.symmetric(vertical: 12);
  static const edgeInsetsV24 = EdgeInsets.symmetric(vertical: 24);

  static const edgeInsetsA4 = EdgeInsets.all(4);
  static const edgeInsetsA8 = EdgeInsets.all(8);
  static const edgeInsetsA12 = EdgeInsets.all(12);
  static const edgeInsetsA16 = EdgeInsets.all(16);
  static const edgeInsetsA20 = EdgeInsets.all(20);
  static const edgeInsetsA24 = EdgeInsets.all(24);

  static const edgeInsetsR4 = EdgeInsets.only(right: 4);
  static const edgeInsetsR8 = EdgeInsets.only(right: 8);
  static const edgeInsetsR12 = EdgeInsets.only(right: 12);
  static const edgeInsetsR16 = EdgeInsets.only(right: 16);
  static const edgeInsetsR20 = EdgeInsets.only(right: 20);
  static const edgeInsetsR24 = EdgeInsets.only(right: 24);

  static const edgeInsetsL4 = EdgeInsets.only(left: 4);
  static const edgeInsetsL8 = EdgeInsets.only(left: 8);
  static const edgeInsetsL12 = EdgeInsets.only(left: 12);
  static const edgeInsetsL16 = EdgeInsets.only(left: 16);
  static const edgeInsetsL20 = EdgeInsets.only(left: 20);
  static const edgeInsetsL24 = EdgeInsets.only(left: 24);

  static const edgeInsetsT4 = EdgeInsets.only(top: 4);
  static const edgeInsetsT8 = EdgeInsets.only(top: 8);
  static const edgeInsetsT12 = EdgeInsets.only(top: 12);
  static const edgeInsetsT24 = EdgeInsets.only(top: 24);

  static const edgeInsetsB4 = EdgeInsets.only(bottom: 4);
  static const edgeInsetsB8 = EdgeInsets.only(bottom: 8);
  static const edgeInsetsB12 = EdgeInsets.only(bottom: 12);
  static const edgeInsetsB24 = EdgeInsets.only(bottom: 24);

  static BorderRadius radius4 = BorderRadius.circular(6);
  static BorderRadius radius8 = BorderRadius.circular(12);
  static BorderRadius radius12 = BorderRadius.circular(16);
  static BorderRadius radius24 = BorderRadius.circular(28);
  static BorderRadius radius32 = BorderRadius.circular(36);
  static BorderRadius radius48 = BorderRadius.circular(50);

  /// 顶部状态栏的高度
  static double get statusBarHeight => MediaQuery.of(Get.context!).padding.top;

  /// 底部导航条的高度
  static double get bottomBarHeight =>
      MediaQuery.of(Get.context!).padding.bottom;

  static Divider get divider => Divider(
        height: 0.5,
        thickness: 0.5,
        indent: 16,
        endIndent: 16,
        color: Colors.grey.withAlpha(35),
      );
}
