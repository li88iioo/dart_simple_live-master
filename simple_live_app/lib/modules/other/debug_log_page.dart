import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/theme/slive_theme.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_icon_button.dart';
import 'package:simple_live_app/widgets/glass/slive_glass_surface.dart';
import 'package:simple_live_app/widgets/glass/slive_page_scaffold.dart';

class DebugLogPage extends StatelessWidget {
  const DebugLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return SlivePageScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 68,
        leadingWidth: 68,
        leading: Align(
          child: SliveGlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回',
            onPressed: () => Get.back(),
          ),
        ),
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '调试日志',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.28,
                  ),
            ),
            Obx(
              () => Text(
                '${Log.debugLogs.length} 条记录',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
        actions: [
          SliveGlassIconButton(
            icon: Icons.ios_share_rounded,
            tooltip: '导出日志',
            onPressed: _shareLogs,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SliveGlassIconButton(
              icon: Icons.clear_all_rounded,
              tooltip: '清空日志',
              onPressed: Log.debugLogs.clear,
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (Log.debugLogs.isEmpty) {
          return const _EmptyLogState();
        }

        return ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: Log.debugLogs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          padding: EdgeInsets.fromLTRB(
            SliveLayout.pageHorizontal,
            10,
            SliveLayout.pageHorizontal,
            MediaQuery.viewPaddingOf(context).bottom + 24,
          ),
          itemBuilder: (_, index) {
            final item = Log.debugLogs[index];
            return RepaintBoundary(child: _LogCard(item: item));
          },
        );
      }),
    );
  }

  Future<void> _shareLogs() async {
    final message = Log.debugLogs
        .map((item) => '${item.datetime}\r\n${item.content}')
        .join('\r\n\r\n');
    final directory = await getApplicationDocumentsDirectory();
    final logFile = File(
      '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.log',
    );
    await logFile.writeAsString(message);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(logFile.path)]),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.item});

  final DebugLogModel item;

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;
    final accent = item.color ?? colors.ambientAccent;

    return SliveGlassSurface(
      variant: SliveGlassVariant.card,
      radius: SliveRadii.card,
      enableBackdropBlur: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.datetime.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            item.content,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Color.lerp(accent, colors.textPrimary, 0.52),
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLogState extends StatelessWidget {
  const _EmptyLogState();

  @override
  Widget build(BuildContext context) {
    final colors = context.sliveColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SliveGlassSurface(
            variant: SliveGlassVariant.panel,
            radius: SliveRadii.panel,
            enableBackdropBlur: true,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: colors.ambientBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: colors.ambientBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  '暂无调试日志',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '运行期间产生的调试信息会稳定保留在这里。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
