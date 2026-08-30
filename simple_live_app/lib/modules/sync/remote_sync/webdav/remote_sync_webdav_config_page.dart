import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/remote_sync_webdav_controller.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';
import 'package:simple_live_app/widgets/none_border_circular_textfield.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class RemoteSyncWebDAVConfigPage extends StatefulWidget {
  const RemoteSyncWebDAVConfigPage({super.key});

  @override
  State<RemoteSyncWebDAVConfigPage> createState() =>
      _RemoteSyncWebDAVConfigPageState();
}

class _RemoteSyncWebDAVConfigPageState
    extends State<RemoteSyncWebDAVConfigPage> {
  late TextEditingController _urlController;
  late TextEditingController _userNameController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    _urlController = TextEditingController();
    _userNameController = TextEditingController();
    _passwordController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;

    return SlivePageScaffold(
      appBar: AppBar(
        title: const Text('WebDAV 账号配置'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SliveGlassIconButton(
              icon: Icons.help_outline_rounded,
              tooltip: '配置帮助',
              onPressed: _showHelp,
            ),
          ),
        ],
      ),
      body: GetX<RemoteSyncWebDAVController>(
        builder: (controller) {
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              SliveLayout.pageHorizontal,
              4,
              SliveLayout.pageHorizontal,
              bottomPadding,
            ),
            children: [
              SliveGlassSurface(
                variant: SliveGlassVariant.panel,
                enableBackdropBlur: true,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ConfigIconBox(
                      icon: Icons.cloud_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '连接你的 WebDAV 服务',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '服务器地址需以 http:// 或 https:// 开头。',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                      height: 1.45,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SettingsCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NoneBorderCircularTextField(
                        editingController: _urlController,
                        labelText: 'WebDAV 服务器地址',
                        hintText: 'https://example.com/dav/',
                        prefixIcon: const Icon(Icons.public_rounded),
                        needPadding: false,
                        trailing: _FieldActionButton(
                          icon: Icons.close_rounded,
                          tooltip: '清空服务器地址',
                          onTap: _urlController.clear,
                        ),
                      ),
                      const SizedBox(height: 12),
                      NoneBorderCircularTextField(
                        editingController: _userNameController,
                        labelText: '账号',
                        prefixIcon: const Icon(Icons.account_circle_outlined),
                        needPadding: false,
                        trailing: _FieldActionButton(
                          icon: Icons.close_rounded,
                          tooltip: '清空账号',
                          onTap: _userNameController.clear,
                        ),
                      ),
                      const SizedBox(height: 12),
                      NoneBorderCircularTextField(
                        editingController: _passwordController,
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        obscureText: controller.passwordVisible.value,
                        needPadding: false,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FieldActionButton(
                              icon: Icons.close_rounded,
                              tooltip: '清空密码',
                              onTap: _passwordController.clear,
                            ),
                            _FieldActionButton(
                              icon: controller.passwordVisible.value
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              tooltip: controller.passwordVisible.value
                                  ? '显示密码'
                                  : '隐藏密码',
                              onTap: controller.changePasswordVisible,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.login_rounded, size: 20),
                          label: const Text('登录'),
                          onPressed: () {
                            controller.doWebDAVLogin(
                              _urlController.text,
                              _userNameController.text,
                              _passwordController.text,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showHelp() {
    Utils.showInformationHelpDialog(
      content: [
        const Text('此功能可以将您的数据备份到 WebDAV 服务器中或者进行数据恢复。\n'),
        const Text(
          'WebDAV 服务器地址请以 http:// 或 https:// 开头，如坚果云（点击复制）：',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: InkWell(
            onTap: () {
              Clipboard.setData(
                const ClipboardData(text: 'https://dav.jianguoyun.com/dav/'),
              );
              SmartDialog.showToast('复制成功');
            },
            child: const Text('https://dav.jianguoyun.com/dav/'),
          ),
        ),
      ],
    );
  }
}

class _ConfigIconBox extends StatelessWidget {
  const _ConfigIconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.13),
        borderRadius: BorderRadius.circular(SliveRadii.control),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}

class _FieldActionButton extends StatelessWidget {
  const _FieldActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(SliveRadii.pill),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 36,
          child: Icon(
            icon,
            size: 19,
            color: context.sliveColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
