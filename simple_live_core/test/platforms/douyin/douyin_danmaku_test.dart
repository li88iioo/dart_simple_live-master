import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:simple_live_core/src/platforms/douyin/douyin_danmaku.dart';
import 'package:simple_live_core/src/platforms/douyin/proto/douyin.pb.dart';
import 'package:test/test.dart';

void main() {
  test('ACK 保持 ack payloadType 并把 internalExt 写入 payload', () {
    final logId = Int64(123456789);
    const internalExt = 'cursor=abc|fetch_time=123';

    final encoded = buildDouyinAckFrame(logId, internalExt).writeToBuffer();
    final decoded = PushFrame.fromBuffer(encoded);

    expect(decoded.payloadType, 'ack');
    expect(decoded.logId, logId);
    expect(utf8.decode(decoded.payload), internalExt);
  });

  test('备用节点使用不同明确 host 并保留路径和查询参数', () {
    final primary = Uri(
      scheme: 'wss',
      host: douyinPrimaryWebSocketHost,
      path: '/webcast/im/push/v2/',
      queryParameters: const {
        'room_id': '100',
        'signature': 'signed-value',
      },
    );

    final backup = buildDouyinBackupWebSocketUri(primary);

    expect(backup.host, douyinBackupWebSocketHost);
    expect(backup.host, isNot(primary.host));
    expect(backup.scheme, primary.scheme);
    expect(backup.path, primary.path);
    expect(backup.queryParameters, primary.queryParameters);
  });

  test('拒绝把备用节点再次当作主节点生成备用地址', () {
    final alreadyBackup = Uri.parse(
      'wss://$douyinBackupWebSocketHost/webcast/im/push/v2/',
    );

    expect(
      () => buildDouyinBackupWebSocketUri(alreadyBackup),
      throwsArgumentError,
    );
  });
}
