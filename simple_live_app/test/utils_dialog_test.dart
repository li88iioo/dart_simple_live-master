import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';

void main() {
  testWidgets('文本编辑弹窗使用自定义按钮并安全释放输入控制器', (tester) async {
    String? result;

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppStyle.light(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6F8FD8),
          ),
          glassMode: SliveGlassMode.soft,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Utils.showEditTextDialog(
                  '旧值',
                  title: '编辑内容',
                  confirm: '保存',
                  cancel: '返回',
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '新值');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(result, '新值');
    expect(tester.takeException(), isNull);
  });
}
