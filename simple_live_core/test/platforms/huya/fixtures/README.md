# Huya gift wire fixtures

`gift_wire.json` 是按外部协议定义独立用 Python JCE 编码后冻结的二进制测试输入，
**不是线上抓包**，也不调用待测 Dart 模型的 `writeTo`。用户名、主播 UID、礼物 ID
（9907）、金额和 example.com URL 全为测试值，不能用来维护真实礼物映射。

- `word`：6502 / SendItemNoticeWordBroadcastPacket。tag 1 为整数数量，
  tag 3 为 senderUid，tag 5 为 presenterUid，tag 19 为 roomId。
- `game`：6507 / SendItemNoticeGameBroadcastPacket。tag 1 为整数数量，
  tag 2 不存在，tag 3/5 为 senderUid/presenterUid，tag 9 为 roomId。
- `gameWrongPresenter`：senderUid 恰好为当前主播，presenterUid 属于其他房间。
- `gameZeroCount`：数量为零，不应虚构一次有效送礼。
- `nonResource16`：6501 的 ItemEffectBizData.iType=16 内层 NonResourceItemEffect，
  tag 0 为 propsUrl；tag 3 包含 vWebSpecilInfo -> vPropsIdentity / vPropsIdentityGod；
  tag 6 为 propsYb，tag 7 为字符串 propsId；含被跳过的合法 struct/vector 字段。

协议依据：

- 独立广播结构：hwenjie/huya_danmu 固定提交
  `ca6efff89f3972dfff28632db5ff2a00b28eb527`，`src/lib/HUYA.js` 404–524 行，
  `src/lib/TafMx.js` 12–19 行。它们是兼容旧网页广播的定义；不能假定如今每个
  “虎牙一号”都会发送 6507，也不能将所有其他 URI 按 6501 解码。
- 16 类业务扩展：虎牙官方网页 `room_normal_402a31e4.js` 引用的
  `https://a.msstatic.com/huya/main3/assets.modules-bffdb441_3b426d0f.js` 中
  `gameLiveBase.js` 模块的 NonResourceItemEffect / PropsWebExtInfo /
  PropsIdentityV2 / PropsIdentityGodV2，及同版本 `gift.ts` 对 type=16 的解析分支。

这些 fixtures 与原有 6501 真实抓包用例互补。跨 URI 测试必须使用各自结构，
不允许拿同一段 6501 payload 更换 URI 后声称通过真实协议测试。

6502/6507 字段已再次与当前房间 TT_PLAYER_CONF.tafSignal 指向的官方文件交叉核对：
`https://fedlib.msstatic.com/fedbasic/huyabaselibs/taf-signal/taf-signal.global.0.1.2.prod.js`。
同文件也提供 6508 / SendItemActivityNoticeBroadcastPacket、6514 /
SendItemOtherBroadcastPacket、1020001 / GuardianPresenterInfoNotice 的独立定义。
6508 的 effectId/frames 不是礼物 ID/数量；6514 的 vItemInfo 是多项 Int64 数量；
1020001 的 NEW=0、ENTER=1，而 6249 只有人数，不能产生开通事件。

- `specialGiftAsciiV2`：6501 type16 只有 ASCII URL，JCE 长度头也是有效
  UTF-8 字节；验证 Core → App 两种卡片不会将其误展示为互动文案。

复现（Python 3 标准库，不需要网络或 Dart 模型）：

```sh
python3 simple_live_core/test/platforms/huya/fixtures/generate_gift_fixtures.py
```

- `effectBeforeTransactionV1` / `transactionGroup1V1` / `transactionGroup2V1`
  / `transactionGroup2ReplayV1`：先到 6541 特效、后到 6501 两个 itemGroup
  （数量 2 和 3）及第二组支付重传。验证 Core 的 `eventId` / `replacesEventId`
  传到 App 后原位替换第一张卡片且数量 2+3=5，重复通知不重播。
