import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';

void main() {
  testWidgets('数字设置在窄屏大字体下保持尺寸并响应步进', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final value = ValueNotifier<int>(16);
    addTearDown(value.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppStyle.light(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6F8FD8),
          ),
          glassMode: SliveGlassMode.soft,
        ),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ValueListenableBuilder<int>(
                  valueListenable: value,
                  builder: (context, current, child) {
                    return SettingsCard(
                      child: SettingsNumber(
                        title: '文字大小',
                        value: current,
                        min: 8,
                        max: 36,
                        onChanged: (next) => value.value = next,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('文字大小'), findsOneWidget);

    await tester.tap(find.byTooltip('增加文字大小'));
    await tester.pump();

    expect(value.value, 17);
    expect(tester.takeException(), isNull);
  });
}
