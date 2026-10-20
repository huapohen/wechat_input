import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/keyboard.dart';
import '../theme.dart';
import '../widgets/common.dart';

class KeyboardDemoPage extends StatefulWidget {
  final String initialMode;
  const KeyboardDemoPage({super.key, this.initialMode = 't9'});

  @override
  State<KeyboardDemoPage> createState() => _KeyboardDemoPageState();
}

class _KeyboardDemoPageState extends State<KeyboardDemoPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final HostTextEditing _host;
  late String _mode = widget.initialMode;

  @override
  void initState() {
    super.initState();
    _host = HostTextEditing(controller: _controller, focusNode: _focus);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('键盘体验'),
        actions: [
          IconButton(
            tooltip: '复制输入内容',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _controller.text));
              if (mounted) showToast(context, '已复制输入框内容');
            },
            icon: const Icon(Icons.copy_rounded, size: 20),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: () {
              _host.clear();
              setState(() {});
            },
            icon: const Icon(Icons.delete_sweep_outlined, size: 21),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 8),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _ModeChip(
                              label: kModeNames[_mode] ?? _mode,
                              icon: kModeIcons[_mode] ?? Icons.keyboard,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                state.standalone ? '单机 · 本地词库' : '本地词库 · 可选联网 AI',
                                style: const TextStyle(
                                    fontSize: 10.5, color: AppColors.accentDark),
                              ),
                            ),
                            const Spacer(),
                            Text('${_controller.text.length} 字',
                                style: TextStyle(fontSize: 11, color: secondary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _controller,
                                focusNode: _focus,
                                readOnly: true,
                                showCursor: true,
                                maxLines: null,
                                minLines: 5,
                                keyboardType: TextInputType.multiline,
                                style: const TextStyle(fontSize: 18, height: 1.6),
                                decoration: InputDecoration(
                                  hintText: '点击这里，然后用下方键盘输入…\n试试输入 nihao，选择「你好」上屏。',
                                  hintStyle: TextStyle(
                                      fontSize: 15,
                                      color: secondary.withValues(alpha: .7),
                                      height: 1.6),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => setState(() {}),
                                onTap: () {
                                  _focus.requestFocus();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded,
                                      size: 18, color: AppColors.accentDark),
                                  const SizedBox(width: 6),
                                  const Text('试一试',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• 九宫格：依次按 6 4 4 2 6，候选出现「你好」\n'
                                '• 全键盘：输入 nihao 或简拼 nh\n'
                                '• 中/英切换：底行「中/英」\n'
                                '• 长按空格：打开系统语音识别\n'
                                '• 工具栏：剪贴板、常用语、问 AI、翻译、文字整理',
                                style: TextStyle(
                                    fontSize: 12.5, color: secondary, height: 1.8),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                            ClipboardData(text: _controller.text));
                                        if (context.mounted) {
                                          showToast(context, '已复制到剪贴板');
                                        }
                                      },
                                      icon: const Icon(Icons.copy_all_outlined,
                                          size: 18),
                                      label: const Text('复制上屏内容'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          Navigator.pushNamed(context, '/keyboard/manage'),
                                      icon: const Icon(Icons.tune_rounded, size: 18),
                                      label: const Text('键盘管理'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '候选排序：固定词/用户词频优先，其次精确前缀、短语、模糊拼音。长按候选可固定或删除。',
                          style: TextStyle(fontSize: 10.5, color: secondary, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          InAppKeyboard(
            host: _host,
            initialMode: widget.initialMode,
            onModeChanged: (mode) => setState(() => _mode = mode),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ModeChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accentDark),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentDark)),
        ],
      ),
    );
  }
}
