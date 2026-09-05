import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_event.dart';
import 'package:simple_live_app/modules/live_room/gift/huya_gift_danmaku_overlay.dart';
import 'package:simple_live_core/simple_live_core.dart';

const _presenter = 2272316519;
// 独立 Python JCE 编码器生成的 fixture，不调用待测 Dart 模型的 writeTo。
final _fixtures = jsonDecode(File(
  '../simple_live_core/test/platforms/huya/fixtures/gift_wire.json',
).readAsStringSync()) as Map;
Uint8List _wire(String key) =>
    base64Decode(_fixtures[key]['commandBase64'] as String);

void main() {
  for (final placement in HuyaGiftOverlayPlacement.values) {
    testWidgets('完整链路 ${placement.name} 特效原位补数量，各交易分组不丢失或重播', (tester) async {
      final events = <HuyaGiftDanmakuEvent>[];
      final queue = HuyaGiftDanmakuQueue();
      final decoder = HuyaDanmaku()
        ..danmakuArgs =
            HuyaDanmakuArgs(ayyuid: _presenter, topSid: 1, subSid: 2)
        ..onMessage = (message) {
          final event = HuyaGiftDanmakuEvent.fromMessage(message,
              sequence: events.length + 1);
          events.add(event);
          queue.enqueue(event);
        };
      Future<void> showActive() => tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: HuyaGiftPresentation(
                  key: ValueKey(queue.active!.id),
                  event: queue.active!,
                  placement: placement,
                  maxWidth: 280,
                  reduceMotion: true,
                ),
              ),
            ),
          ));

      decoder.decodeMessage(_wire('effectBeforeTransactionV1'));
      final initialId = queue.active!.id;
      await showActive();
      final initialElement = tester.element(find.byType(HuyaGiftPresentation));
      expect(find.text('×1'), findsNothing); // 特效不知道数量，不能伪造一件。
      expect(events.single.countKnown, isFalse);

      decoder.decodeMessage(_wire('transactionGroup1V1'));
      await showActive();
      expect(events, hasLength(2)); // 第二次回调是替换，不是新送礼。
      expect(events.last.isUpdate, isTrue);
      expect(queue.active!.id, initialId);
      expect(tester.element(find.byType(HuyaGiftPresentation)),
          same(initialElement));
      expect(queue.pendingCount, 0);
      expect(find.text('×2'), findsOneWidget);
      expect(queue.active!.isHighlight, isTrue);

      decoder.decodeMessage(_wire('transactionGroup2V1'));
      decoder.decodeMessage(_wire('transactionGroup2ReplayV1'));
      expect(events, hasLength(3)); // 同分组的支付重传不新增回调。
      expect(events.last.isUpdate, isFalse);
      expect(queue.pendingCount, 1);
      expect(events.skip(1).fold<int>(0, (n, e) => n + e.count), 5);
      queue.advance();
      await showActive();
      expect(find.text('×3'), findsOneWidget);
      expect(queue.pendingCount, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
