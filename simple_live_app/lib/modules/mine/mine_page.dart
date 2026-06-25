import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/signalr_service.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  Widget _buildLeadingIcon(BuildContext context, IconData icon, Color baseColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Premium translucent pastel style (translucent background with matching colored icon)
    Color iconColor = baseColor;
    Color bgColor = baseColor.withOpacity(isDark ? 0.20 : 0.12);
    
    if (baseColor == const Color(0xFF24292E)) { // GitHub color
      iconColor = isDark ? Colors.white70 : const Color(0xFF24292E);
      bgColor = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFF24292E).withOpacity(0.1);
    } else if (baseColor == Colors.blueGrey) {
      iconColor = isDark ? const Color(0xFFB0BEC5) : Colors.blueGrey.shade700;
    } else {
      if (isDark) {
        // Pastel adaptation in dark mode
        if (baseColor == Colors.blue) iconColor = const Color(0xFF64B5F6);
        else if (baseColor == Colors.green) iconColor = const Color(0xFF81C784);
        else if (baseColor == Colors.teal) iconColor = const Color(0xFF4DB6AC);
        else if (baseColor == Colors.orange) iconColor = const Color(0xFFFFB74D);
        else if (baseColor == Colors.indigo) iconColor = const Color(0xFF9FA8DA);
        else if (baseColor == Colors.pink) iconColor = const Color(0xFFF48FB1);
        else if (baseColor == Colors.purple) iconColor = const Color(0xFFCE93D8);
        else if (baseColor == Colors.cyan) iconColor = const Color(0xFF80DEEA);
        else if (baseColor == Colors.amber.shade700) iconColor = const Color(0xFFFFD54F);
        else if (baseColor == Colors.redAccent) iconColor = const Color(0xFFEF9A9A);
        else if (baseColor == Colors.redAccent.shade100) iconColor = const Color(0xFFFF8A80);
      } else {
        // Solid accent adaptation in light mode
        if (baseColor == Colors.green) iconColor = const Color(0xFF2E7D32);
        else if (baseColor == Colors.orange) iconColor = const Color(0xFFE65100);
        else if (baseColor == Colors.amber.shade700) iconColor = const Color(0xFFD84315);
      }
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          icon,
          color: iconColor,
          size: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              systemNavigationBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              systemNavigationBarColor: Colors.transparent,
            ),
      child: SafeArea(
        child: ListView(
          padding: AppStyle.edgeInsetsA16.copyWith(top: 8, bottom: 80),
          children: [
            // App About / Profile Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.withAlpha(25) : Colors.white,
                borderRadius: AppStyle.radius12,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                  width: 0.5,
                ),
              ),
              child: ListTile(
                leading: Image.asset(
                  'assets/images/logo.png',
                  width: 48,
                  height: 48,
                ),
                title: const Text(
                  "Slive",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  "我就默默看你表演",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
                onTap: () {
                  Get.dialog(AboutDialog(
                    applicationIcon: Image.asset(
                      'assets/images/logo.png',
                      width: 48,
                      height: 48,
                    ),
                    applicationName: "Slive",
                    applicationVersion: "我就默默看你表演",
                    applicationLegalese: "Ver ${Utils.packageInfo.version}",
                  ));
                },
              ),
            ),
            const SizedBox(height: 16),

            // Group 1: User data & tools
            _buildCard(
              context,
              children: [
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.history_line, Colors.blue),
                  title: const Text("观看记录", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kHistory);
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.account_circle_line, Colors.green),
                  title: const Text("账号管理", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSettingsAccount);
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(context, Icons.devices, Colors.teal),
                  title: const Text("数据同步", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSync);
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.link, Colors.orange),
                  title: const Text("链接解析", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kTools);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Group 2: Settings
            _buildCard(
              context,
              children: [
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.moon_line, Colors.indigo),
                  title: const Text("外观设置", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kAppstyleSetting);
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.home_2_line, Colors.pink),
                  title: const Text("主页设置", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSettingsIndexed);
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.play_circle_line, Colors.purple),
                  title: const Text("直播设置", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSettingsPlay);
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.text, Colors.cyan),
                  title: const Text("弹幕设置", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSettingsDanmu);
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.timer_2_line, Colors.amber.shade700),
                  title: const Text("定时关闭", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSettingsAutoExit);
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.apps_line, Colors.blueGrey),
                  title: const Text("其他设置", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Get.toNamed(RoutePath.kSettingsOther);
                  },
                ),
                if (kDebugMode)
                  ListTile(
                    leading: _buildLeadingIcon(context, Remix.bug_line, Colors.redAccent),
                    title: const Text("测试", style: TextStyle(fontSize: 14)),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                    onTap: () async {
                      SignalRService signalRService = SignalRService();
                      await signalRService.connect();
                      var room = await signalRService.createRoom();
                      Log.logPrint(room);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Group 3: Support
            _buildCard(
              context,
              children: [
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.error_warning_line, Colors.redAccent.shade100),
                  title: const Text("免责声明", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: Utils.showStatement,
                ),
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.github_line, const Color(0xFF24292E)),
                  title: const Text("开源主页", style: TextStyle(fontSize: 14)),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    launchUrlString(
                      "https://github.com/slotsun/dart_simple_live",
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                ListTile(
                  leading: _buildLeadingIcon(context, Remix.upload_2_line, Colors.redAccent),
                  title: const Text("检查更新", style: TextStyle(fontSize: 14)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Ver ${Utils.packageInfo.version}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      AppStyle.hGap4,
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  onTap: () {
                    Utils.checkUpdate(showMsg: true);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Widget> dividedChildren = [];
    for (int i = 0; i < children.length; i++) {
      dividedChildren.add(children[i]);
      if (i < children.length - 1) {
        dividedChildren.add(
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 56,
            endIndent: 0,
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
          ),
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.withAlpha(25) : Colors.white,
        borderRadius: AppStyle.radius12,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppStyle.radius12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: dividedChildren,
        ),
      ),
    );
  }
}
