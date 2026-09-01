/// 用于让跨多个 await 的异步流程只提交最新一代结果。
///
/// 调用方在启动新流程或销毁当前流程时调用 [next]，并在每个异步边界后
/// 使用 [isCurrent] 验证令牌。旧流程可以自然完成，但不能再修改当前状态。
class OperationGeneration {
  int _value = 0;

  int get current => _value;

  int next() => ++_value;

  bool isCurrent(int token) => token == _value;
}
