import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ClipboardPage extends StatefulWidget {
  const ClipboardPage({super.key});

  @override
  State<ClipboardPage> createState() => _ClipboardPageState();
}

class _ClipboardPageState extends State<ClipboardPage> {
  bool _reading = false;
  bool _syncing = false;
  String? _error;

  Future<void> _readClipboard() async {
    final state = AppScope.read(context);
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        setState(() => _error = '系统剪贴板没有文本内容，或系统不允许读取。');
      } else {
        await state.addClipboard(text);
        if (mounted) showToast(context, '已记录剪贴板内容');
      }
    } catch (e) {
      setState(() => _error = '读取剪贴板失败：$e');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _sync(AppState state) async {
    if (!state.syncConnected) {
      setState(() => _error = '尚未配对设备。请先到「跨设备粘贴同步」生成或输入 6 位配对码。');
      return;
    }
    setState(() {
      _syncing = true;
      _error = null;
    });
    final api = ApiClient.fromState(state);
    try {
      final peerToken = state.syncPeerToken;
      if (peerToken.isNotEmpty) {
        final peerItems = await api.pullClipboard(peerToken);
        final merged = <String>[...peerItems, ...state.clipboard];
        final unique = <String>[];
        for (final item in merged) {
          if (!unique.contains(item)) unique.add(item);
        }
        await state.setClipboard(unique);
        if (mounted) {
          showToast(context, '已从「${state.syncPeer}」拉取 ${peerItems.length} 条');
        }
      } else {
        final items = await api.pushClipboard(state.syncToken, state.clipboard);
        await state.setClipboard(items);
        if (mounted) showToast(context, '已上传 ${items.length} 条到本机同步空间');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '同步失败：$e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final items = state.clipboard;
    return SettingsScaffold(
      title: '剪贴板',
      subtitle: '保存你主动读取的文本。剪贴板历史不会自动采集，也不会写入日志。',
      actions: [
        IconButton(
          tooltip: '同步',
          onPressed: _syncing ? null : () => _sync(state),
          icon: _syncing
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync_rounded, size: 21),
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _reading ? null : _readClipboard,
                icon: _reading
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.content_paste_go_rounded, size: 18),
                label: const Text('读取系统剪贴板'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: items.isEmpty
                    ? null
                    : () async {
                        final ok = await confirmAction(context,
                            title: '清空剪贴板历史',
                            message: '将删除本机保存的 ${items.length} 条记录。',
                            confirm: '清空',
                            danger: true);
                        if (ok) await state.setClipboard([]);
                      },
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('清空历史'),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(
            message: _error!,
            onRetry: () {
              setState(() => _error = null);
              _readClipboard();
            },
            onDismiss: () => setState(() => _error = null),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Text('历史记录',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dark ? AppColors.darkText : AppColors.text)),
            const Spacer(),
            Text('${items.length} 条', style: TextStyle(fontSize: 11, color: secondary)),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const AppCard(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: EmptyState(
              icon: Icons.content_paste_off_rounded,
              title: '暂无剪贴板记录',
              subtitle: '复制一段文本后，点击上方「读取系统剪贴板」。',
            ),
          )
        else
          ...List.generate(items.length, (index) {
            final text = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (context.mounted) showToast(context, '已复制');
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, height: 1.45)),
                            const SizedBox(height: 4),
                            Text('点击复制 · ${text.length} 字符',
                                style: TextStyle(fontSize: 9.5, color: secondary)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '删除',
                      onPressed: () => state.removeClipboardAt(index),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      visualDensity: VisualDensity.compact,
                      color: secondary,
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 10),
        InfoBanner(
          text: state.syncConnected
              ? '已配对「${state.syncPeer.isEmpty ? '另一台设备' : state.syncPeer}」。点击右上角同步可拉取对方剪贴板。'
              : '未配对设备。到「跨设备粘贴同步」输入 6 位配对码后，可拉取另一台设备的剪贴板。',
          icon: Icons.devices_other_outlined,
        ),
      ],
    );
  }
}
