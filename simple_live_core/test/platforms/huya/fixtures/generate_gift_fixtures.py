"""独立 Python JCE 编码器：重建冻结 fixture，不调用待测 Dart 模型。

协议来源与数据性质见同目录 README.md。仅使用 Python 3 标准库。
"""

import base64
import json
import struct
from pathlib import Path


def head(tag, kind):
    return bytes([(min(tag, 15) << 4) | kind]) + (bytes([tag]) if tag >= 15 else b"")


def integer(tag, number):
    if number == 0:
        return head(tag, 12)
    for kind, fmt, low, high in [
        (0, "b", -128, 127),
        (1, "h", -32768, 32767),
        (2, "i", -(2**31), 2**31 - 1),
        (3, "q", -(2**63), 2**63 - 1),
    ]:
        if low <= number <= high:
            return head(tag, kind) + struct.pack(">" + fmt, number)
    raise ValueError("JCE integer outside signed int64")


def string(tag, value):
    data = value.encode("utf-8")
    if len(data) < 256:
        return head(tag, 6) + bytes([len(data)]) + data
    return head(tag, 7) + struct.pack(">I", len(data)) + data


def record(tag, fields):
    return head(tag, 10) + b"".join(fields) + head(0, 11)


def vector(tag, items):
    return head(tag, 9) + integer(0, len(items)) + b"".join(items)


def raw_bytes(tag, data):
    return head(tag, 13) + head(0, 0) + integer(0, len(data)) + data


def encoded(data):
    return base64.b64encode(data).decode("ascii")


def make_fixtures():
    presenter, sender = 2272316519, 10001
    fixtures = {}

    def add(name, uri, fields):
        fixtures[name] = {"uri": uri, "payloadBase64": encoded(b"".join(fields))}

    add("word", 6502, [
        integer(0, 9907), integer(1, 3), integer(2, 12345),
        integer(3, sender), string(4, "测试用户"), integer(5, presenter),
        string(6, "测试主播"), integer(7, 2), integer(8, 3), integer(9, 1),
        integer(12, 32), string(13, "{}"), integer(19, 998),
    ])
    add("game", 6507, [
        integer(0, 9907), integer(1, 3), integer(3, sender),
        string(4, "测试用户"), integer(5, presenter), string(6, "测试主播"),
        integer(7, 12345), integer(8, 67890), integer(9, 998), integer(10, 32),
    ])
    add("gameWrongPresenter", 6507, [
        integer(0, 9907), integer(1, 3), integer(3, presenter),
        string(4, "其他用户"), integer(5, 9), string(6, "其他主播"),
        integer(7, 12345), integer(8, 67890), integer(9, 998), integer(10, 32),
    ])
    add("gameZeroCount", 6507, [
        integer(0, 9907), integer(1, 0), integer(3, sender),
        string(4, "测试用户"), integer(5, presenter),
    ])
    add("nonResource16", 0, [
        string(0, "//cdn.example.com/special/shield.webp"),
        record(1, [integer(0, 1), integer(1, 2), integer(2, 3)]),
        vector(2, []),
        vector(3, [record(0, [
            vector(0, [record(0, [
                string(1, "https://cdn.example.com/special/shield-god.svga"),
            ])]),
            vector(1, [record(0, [
                string(0, "//cdn.example.com/special/shield18.png"),
                string(3, "https://cdn.example.com/special/shield.svga&checksum"),
                string(6, "//cdn.example.com/special/shield108.png"),
                string(17, "https://cdn.example.com/special/shield-vap.json"),
            ])]),
            integer(2, 1),
        ])]),
        integer(4, 0), integer(5, 0), integer(6, 188000),
        string(7, "shield-custom-16"),
    ])

    def add_special(name, resource, payment, message_id):
        gift = b"".join([
            integer(0, 9907), string(1, payment), integer(2, 2),
            integer(3, presenter), integer(4, sender), string(5, "测试主播"),
            string(6, "完整的特殊礼物送礼用户"), string(20, "测试特殊守护礼物"),
            vector(42, [record(0, [integer(0, 16), raw_bytes(1, resource)])]),
        ])
        push = string(0, "live:2272316519") + vector(1, [record(0, [
            integer(0, 6501), raw_bytes(1, gift), integer(2, message_id),
        ])])
        fixtures[name] = {
            "uri": 6501,
            "commandBase64": encoded(integer(0, 22) + raw_bytes(1, push)),
        }

    add_special(
        "specialGiftV2", base64.b64decode(fixtures["nonResource16"]["payloadBase64"]),
        "fixture-payment", 901,
    )
    # ASCII-only Tars 资源仍不是互动文案：长度头恰好是可见字符 &。
    add_special(
        "specialGiftAsciiV2", string(0, "https://cdn.example.com/special/gift.png"),
        "fixture-ascii-payment", 902,
    )
    # 跨协议原位更新：先大额特效，后同支付号的两组真实交易，最后重传第二组。
    def add_v1(name, uri, payload, message_id):
        envelope = b"".join([
            integer(0, 0), integer(1, uri), raw_bytes(2, payload), integer(3, 0),
            string(4, "live:2272316519"), integer(5, message_id),
        ])
        fixtures[name] = {
            "uri": uri,
            "commandBase64": encoded(integer(0, 7) + raw_bytes(1, envelope)),
        }

    params = {"PAYID": "pipeline-payment", "PAYTOTAL": "100000"}
    params_wire = head(9, 8) + integer(0, len(params)) + b"".join(
        string(0, key) + string(1, value) for key, value in params.items()
    )
    effect = b"".join([
        integer(0, presenter), integer(1, 70001), integer(2, 5000000001),
        string(3, "送礼用户"), string(8, "测试礼物"), params_wire,
    ])
    add_v1("effectBeforeTransactionV1", 6541, effect, 10)
    for name, count, group, message_id in [
        ("transactionGroup1V1", 2, 1, 11),
        ("transactionGroup2V1", 3, 2, 12),
        ("transactionGroup2ReplayV1", 3, 2, 13),
    ]:
        transaction = b"".join([
            integer(0, 4), string(1, "pipeline-payment"), integer(2, count),
            integer(3, presenter), integer(4, 5000000001), string(5, "主播"),
            string(6, "送礼用户"), integer(8, count), integer(9, group),
            string(20, "测试礼物"), integer(250, 0),
        ])
        add_v1(name, 6501, transaction, message_id)
    return fixtures


if __name__ == "__main__":
    Path(__file__).with_name("gift_wire.json").write_text(
        json.dumps(make_fixtures(), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
