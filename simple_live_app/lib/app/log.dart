import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/utils.dart';

class Log {
  static final RegExp _sensitiveFieldPattern = RegExp(
    r'''(["']?(?:authorization|cookie|set-cookie|password|passwd|token|secret|credential|session)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)''',
    caseSensitive: false,
  );
  static final RegExp _uriCredentialPattern = RegExp(
    r'(https?://)[^/@\s:]+:[^/@\s]+@',
    caseSensitive: false,
  );

  static LogFileWriter? logFileWriter;
  static void initWriter() {
    logFileWriter = LogFileWriter();
  }

  static void disposeWriter() {
    logFileWriter?.close();
    logFileWriter = null;
  }

  static void writeLog(Object content, [Level level = Level.info]) {
    logFileWriter?.write(
      "[${level.name.toUpperCase()}] $_currentTime：${sanitize(content)}",
    );
  }

  static String sanitize(Object? content) {
    return (content?.toString() ?? 'null')
        .replaceAllMapped(
          _sensitiveFieldPattern,
          (match) => '${match.group(1)}<redacted>',
        )
        .replaceAllMapped(
          _uriCredentialPattern,
          (match) => '${match.group(1)}<redacted>@',
        );
  }

  static RxList<DebugLogModel> debugLogs = <DebugLogModel>[].obs;

  static void addDebugLog(String content, Color? color) {
    if (kReleaseMode) {
      return;
    }
    if (content.contains("请求响应")) {
      content = content.split("\n").join('\n💡 ');
    }
    try {
      debugLogs.insert(0, DebugLogModel(DateTime.now(), content, color: color));
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  static Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );

  static void d(String message, [bool writeFile = true]) {
    message = sanitize(message);
    addDebugLog(message, Colors.orange);
    logger.d("${DateTime.now().toString()}\n$message");
    if (writeFile) {
      writeLog(message, Level.debug);
    }
  }

  static void i(String message, [bool writeFile = true]) {
    message = sanitize(message);
    addDebugLog(message, Colors.blue);
    logger.i("${DateTime.now().toString()}\n$message");
    if (writeFile) {
      writeLog(message, Level.info);
    }
  }

  static void e(String message, StackTrace stackTrace,
      [bool writeFile = true]) {
    message = sanitize(message);
    addDebugLog('$message\r\n\r\n$stackTrace', Colors.red);
    logger.e("${DateTime.now().toString()}\n$message", stackTrace: stackTrace);
    if (writeFile) {
      writeLog("$message\n$stackTrace", Level.error);
    }
  }

  static void w(String message, [bool writeFile = true]) {
    message = sanitize(message);
    addDebugLog(message, Colors.pink);
    logger.w("${DateTime.now().toString()}\n$message");
    if (writeFile) {
      writeLog(message, Level.warning);
    }
  }

  static void logPrint(dynamic obj, [bool writeFile = true]) {
    final content = sanitize(obj);
    addDebugLog(content, Colors.red);
    if (writeFile) {
      writeLog(content, Level.info);
    }
    //logger.e(obj.toString(), obj, obj?.stackTrace);
    if (kDebugMode) {
      print(content);
    }
  }

  static Future<void> flush() async {
    await logFileWriter?.flush();
  }

  static String get _currentTime => Utils.timeFormat.format(DateTime.now());
}

class LogFileWriter {
  late String fileName;
  LogFileWriter() {
    var dt = DateFormat("yyyy-MM-dd HH-mm-ss").format(DateTime.now());
    fileName = "$dt.log";
    initFile();
  }
  IOSink? fileWriter;
  void initFile() async {
    var supportDir = await getApplicationSupportDirectory();
    var logDir = Directory("${supportDir.path}/log");
    if (!await logDir.exists()) {
      await logDir.create();
    }
    var logFile = File("${logDir.path}/$fileName");
    fileWriter = logFile.openWrite(mode: FileMode.append);
    writeSystemInfo();
  }

  void write(String content) {
    fileWriter?.write(content);
    fileWriter?.write("\r\n");
  }

  Future close() async {
    await fileWriter?.close();
  }

  Future<void> flush() async {
    await fileWriter?.flush();
  }

  void writeSystemInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    write("System Info:");
    write("Current Time: ${DateTime.now()}");
    write("Platform: ${Platform.operatingSystem}");
    write("Version: ${Platform.operatingSystemVersion}");
    write("Local: ${Platform.localeName}");
    write(
        "App Version: ${Utils.packageInfo.version}+${Utils.packageInfo.buildNumber}");
    final deviceData = Platform.isAndroid
        ? (await deviceInfo.androidInfo).data
        : Platform.isIOS
            ? (await deviceInfo.iosInfo).data
            : Platform.isLinux
                ? (await deviceInfo.linuxInfo).data
                : Platform.isMacOS
                    ? (await deviceInfo.macOsInfo).data
                    : Platform.isWindows
                        ? (await deviceInfo.windowsInfo).data
                        : const <String, dynamic>{};
    const safeKeys = <String>{
      'brand',
      'device',
      'display',
      'hardware',
      'manufacturer',
      'model',
      'product',
      'systemName',
      'systemVersion',
      'version',
      'kernelVersion',
      'prettyName',
      'release',
      'buildNumber',
    };
    write({
      for (final entry in deviceData.entries)
        if (safeKeys.contains(entry.key)) entry.key: entry.value,
    }.toString());
    write("End System Info");
  }
}

class DebugLogModel {
  final String content;
  final DateTime datetime;
  final Color? color;
  DebugLogModel(this.datetime, this.content, {this.color});
}
