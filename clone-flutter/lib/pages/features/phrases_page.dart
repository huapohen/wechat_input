import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class PhrasesPage extends StatefulWidget {
  const PhrasesPage({super.key});

  @override
  State<PhrasesPage> createState() => _PhrasesPageState();
}

class _PhrasesPageState extends State<PhrasesPage> {
  final TextEditingController _search = TextEditingController();
  bool _syncing = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<PhraseEntry?> _editDialog({PhraseEntry? initial}) async {
    final text = TextEditingController(text: initial?.text ?? '');
    final code = TextEditingController(text: initial?.code ?? '');
    final result = await showDialog<PhraseEntry>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initial == null ? '添加常用语' : '编辑常用语'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: text,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(labelText: '内容'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: code,
              decoration: const InputDecoration(
                labelText: '编码（可选）',
                hintText: '例如 nihao',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final value = text.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(
                  context, PhraseEntry(text: value, code: code.text.trim()));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    text.dispose();
    code.dispose();
    return result;
  }

  Future<void> _sync(AppState state) async {
    if (!state.syncConnected) {
      setState(() => _error = '尚未配对设备。请先到「跨设备粘贴同步」完成配对。');
      return;
    }
    setState(() {
      _syncing = true;
      _error = null;
      _status = null;
    });
    try {
      final token = state.syncPeerToken.isEmpty ? state.syncToken : state.syncPeerToken;
      final merged = await ApiClient.fromState(state).pushPhrases(token, state.phrases);
      await state.setPhrases(merged);
      setState(() => _status = '已合并，当前 ${merged.length} 条常用语');
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
    final query = _search.text.trim().toLowerCase();
    final list = state.phrases
        .where((e) =>
            query.isEmpty ||
            e.text.toLowerCase().contains(query) ||
            e.code.toLowerCase().contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('常用语'),
        actions: [
          IconButton(
            tooltip: '添加',
            onPressed: () async {
              final entry = await _editDialog();
              if (entry != null) await state.addPhrase(entry);
            },
            icon: const Icon(Icons.add_rounded, size: 23),
          ),
          IconButton(
            tooltip: '同步',
            onPressed: _syncing ? null : () => _sync(state),
            icon: _syncing
                ? const SizedBox(
                    width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded, size: 21),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            hintText: '搜索内容或编码',
                            prefixIcon: Icon(Icons.search_rounded, size: 19),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkSurface : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: dark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Text('${list.length}',
                            style: TextStyle(fontSize: 12, color: secondary)),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ErrorBanner(
                      message: _error!,
                      onRetry: () => _sync(state),
                      onDismiss: () => setState(() => _error = null),
                    ),
                  ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: InfoBanner(
                        text: _status!, icon: Icons.check_circle_outline_rounded),
                  ),
                Expanded(
                  child: list.isEmpty
                      ? EmptyState(
                          icon: Icons.format_quote_rounded,
                          title: query.isEmpty ? '暂无常用语' : '没有匹配项',
                          subtitle: '添加常用回复、地址或自我介绍，键盘工具栏可一键插入。',
                          action: FilledButton.icon(
                            onPressed: () async {
                              final entry = await _editDialog();
                              if (entry != null) await state.addPhrase(entry);
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('添加常用语'),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final entry = list[index];
                            final realIndex = state.phrases.indexOf(entry);
                            return AppCard(
                              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                              onTap: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: entry.text));
                                if (context.mounted) showToast(context, '已复制');
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(entry.text,
                                            style: const TextStyle(
                                                fontSize: 14, height: 1.45)),
                                        if (entry.code.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(entry.code,
                                              style: TextStyle(
                                                  fontSize: 10, color: secondary)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '插入到剪贴板',
                                    onPressed: () async {
                                      await Clipboard.setData(
                                          ClipboardData(text: entry.text));
                                      if (context.mounted) {
                                        showToast(context, '已复制，可在键盘中粘贴');
                                      }
                                    },
                                    icon: const Icon(Icons.copy_rounded, size: 17),
                                    visualDensity: VisualDensity.compact,
                                    color: secondary,
                                  ),
                                  IconButton(
                                    tooltip: '编辑',
                                    onPressed: () async {
                                      final edited =
                                          await _editDialog(initial: entry);
                                      if (edited != null) {
                                        await state.updatePhrase(realIndex, edited);
                                      }
                                    },
                                    icon: const Icon(Icons.edit_outlined, size: 17),
                                    visualDensity: VisualDensity.compact,
                                    color: secondary,
                                  ),
                                  IconButton(
                                    tooltip: '删除',
                                    onPressed: () async {
                                      final ok = await confirmAction(context,
                                          title: '删除常用语',
                                          message: '删除「${entry.text}」？',
                                          confirm: '删除',
                                          danger: true);
                                      if (ok) await state.removePhrase(realIndex);
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 17),
                                    visualDensity: VisualDensity.compact,
                                    color: secondary,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 6, 16, MediaQuery.paddingOf(context).bottom + 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final entry = await _editDialog();
                            if (entry != null) await state.addPhrase(entry);
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('添加常用语'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: '键盘中插入',
                        onPressed: () => Navigator.pushNamed(context, '/keyboard'),
                        icon: const Icon(Icons.keyboard_outlined, size: 19),
                      ),
                    ],
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
