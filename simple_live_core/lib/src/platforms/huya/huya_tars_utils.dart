import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

/// TAF 的 BYTE 整数是有符号的，现有 vendored reader 却按 Uint8 读取。
/// 在虎牙适配边界恢复实际 BYTE 的符号，不改变其他平台/正数 SHORT 的语义。
/// [defaultValue] 仅用于缺失的 optional 字段，不能覆盖显式 ZERO_TAG 或负数。
int readHuyaSignedInt(
  TarsInputStream input,
  int tag,
  bool required, {
  int defaultValue = 0,
}) {
  if (!required && input.br.position >= input.br.length) return defaultValue;
  if (!input.skipToTag(tag)) {
    return required ? input.readInt(tag, true) : defaultValue;
  }
  final head = HeadData();
  input.peakHead(head);
  final value = input.readInt(tag, required);
  return head.type == TarsStructType.BYTE.index ? value.toSigned(8) : value;
}
