import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../keyboard/keyboard.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

const Map<String, String> _modeNames = {
  'polish': '文字整理',
  'rewrite': '灵动表达',
  'translate': '翻译',
  'summary': '摘要',
};

const Map<String, String> _samples = {
  'polish': '嗯那个我们今天呢主要是讨论一下这个项目的进度然后呢大概是在下个月的时候会有一个初步的版本然后风险的话就是人手可能不太够',
  'rewrite': '今天加班到很晚，终于把方案改完了。',
  'translate': '输入法的候选排序应该优先考虑用户的学习习惯，而不是只看词频。',
  'summary': '今天开会讨论了三个问题。第一，版本进度比计划晚两天，需要在本周补上。第二，测试资源不足，优先级需要重新排序。第三，文件传输在弱网下会超时，需要增加重试与进度提示。',
};

class TextToolsPage extends StatefulWidget {
  final String initialMode;
  final String initialText;
  const TextToolsPage({
    super.key,
    this.initialMode = 'polish',
    this.initialText = '',
  });

  @override
  State<TextToolsPage> createState() => _TextToolsPageState();
}

class _TextToolsPageState extends State<TextToolsPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final HostTextEditing _host;
  late String _mode = widget.initialMode;
  bool _useInApp = false;
  bool _loading = false;
  String? _error;
  String? _result;
  List<String> _candidates = const [];
  String? _summaryText;
  List<String> _bullets = const [];
  String? _undo;
  String _target = 'en';
  String _style = '自然';

  AppState get _state => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    _host = HostTextEditing(controller: _controller, focusNode: _focus);
    _controller.text = widget.initialText;
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请先输入要处理的文字');
      return;
    }
    if (_state.standalone) {
      setState(() => _error = '单机模式已开启。AI 文字工具不可用，请先关闭单机模式。');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _candidates = const [];
      _summaryText = null;
      _bullets = const [];
    });
    final api = ApiClient.fromState(_state);
    try {
      switch (_mode) {
        case 'polish':
          final result = await api.polish(text);
          setState(() => _result = result);
        case 'rewrite':
          final candidates = await api.rewrite(text, style: _style, count: 3);
          setState(() {
            _candidates = candidates;
            _result = candidates.isEmpty ? null : candidates.first;
          });
          if (candidates.isEmpty) throw ApiException('服务没有返回改写候选');
        case 'translate':
          final result = await api.translate(text, target: _target);
          setState(() => _result = result);
        case 'summary':
          final data = await api.summarize(text);
          final bullets = data['bullets'];
          setState(() {
            _summaryText = (data['summary'] ?? data['text'] ?? '').toString();
            _result = (data['text'] ?? data['summary'] ?? '').toString();
            _bullets = bullets is List
                ? bullets.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
                : const [];
          });
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyText(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _undo = _controller.text;
      _controller.text = text.trim();
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    });
    showToast(context, '已应用到输入框，可撤销');
  }

  void _undoApply() {
    final undo = _undo;
    if (undo == null) return;
    setState(() {
      _controller.text = undo;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
      _undo = null;
    });
    showToast(context, '已撤销');
  }

  String get _targetName =>
      const {'zh': '中文', 'en': 'English', 'ja': '日本語', 'ko': '한국어'}[_target] ?? _target;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return Scaffold(
      resizeToAvoidBottomInset: !_useInApp,
      appBar: AppBar(
        title: Text('文字工具 · ${_modeNames[_mode] ?? ''}'),
        actions: [
          IconButton(
            tooltip: _useInApp ? '使用系统键盘' : '使用内置键盘',
            onPressed: () {
              setState(() => _useInApp = !_useInApp);
              if (_useInApp) {
                _focus.requestFocus();
                SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
              } else {
                _focus.unfocus();
              }
            },
            icon: Icon(
              _useInApp ? Icons.keyboard_hide_outlined : Icons.keyboard_alt_outlined,
              size: 21,
            ),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (index) {
              if (index == 0) {
                setState(() {
                  _controller.text = _samples[_mode] ?? '';
                  _controller.selection =
                      TextSelection.collapsed(offset: _controller.text.length);
                });
              } else if (index == 1) {
                _undoApply();
              } else if (index == 2) {
                _controller.clear();
                setState(() {
                  _result = null;
                  _candidates = const [];
                  _summaryText = null;
                  _error = null;
                });
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 0, child: Text('填入示例')),
              PopupMenuItem(value: 1, child: Text('撤销应用')),
              PopupMenuItem(value: 2, child: Text('清空')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModeTabs(
                        mode: _mode,
                        onChanged: (mode) => setState(() {
                          _mode = mode;
                          _result = null;
                          _candidates = const [];
                          _summaryText = null;
                          _bullets = const [];
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_useInApp ? '内置键盘输入' : '输入原文',
                                    style: TextStyle(fontSize: 11, color: secondary)),
                                const Spacer(),
                                Text('${_controller.text.length} 字符',
                                    style: TextStyle(fontSize: 10.5, color: secondary)),
                                if (_undo != null) ...[
                                  const SizedBox(width: 6),
                                  TextButton(
                                    onPressed: _undoApply,
                                    style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact),
                                    child: const Text('撤销', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _controller,
                              focusNode: _focus,
                              readOnly: _useInApp,
                              minLines: 4,
                              maxLines: 8,
                              keyboardType: TextInputType.multiline,
                              style: const TextStyle(fontSize: 15, height: 1.6),
                              decoration: InputDecoration(
                                hintText: '粘贴或输入要处理的文字…',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: secondary.withValues(alpha: .7)),
                              ),
                              onTap: () {
                                if (_useInApp) {
                                  _focus.requestFocus();
                                  SystemChannels.textInput
                                      .invokeMethod<void>('TextInput.hide');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      if (_mode == 'rewrite' || _mode == 'translate') ...[
                        const SizedBox(height: 10),
                        if (_mode == 'rewrite')
                          SettingCard(
                            title: '语气',
                            description: '改写会保留原意，不新增事实。',
                            child: SegmentedChoice<String>(
                              value: _style,
                              options: const [
                                MapEntry('自然', '自然'),
                                MapEntry('正式', '正式'),
                                MapEntry('轻松', '轻松'),
                                MapEntry('简洁', '简洁'),
                              ],
                              onChanged: (v) => setState(() => _style = v),
                            ),
                          )
                        else
                          SettingCard(
                            title: '目标语言',
                            description: '源语言自动识别；当前目标：$_targetName。',
                            child: SegmentedChoice<String>(
                              value: _target,
                              options: const [
                                MapEntry('zh', '中文'),
                                MapEntry('en', 'English'),
                                MapEntry('ja', '日本語'),
                                MapEntry('ko', '한국어'),
                              ],
                              onChanged: (v) => setState(() => _target = v),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _generate,
                          icon: _loading
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_awesome_rounded, size: 19),
                          label: Text(_loading
                              ? '正在生成…'
                              : switch (_mode) {
                                  'polish' => '整理文字',
                                  'rewrite' => '生成三种说法',
                                  'translate' => '翻译为$_targetName',
                                  _ => '生成摘要',
                                }),
                        ),
                      ),
                      if (state.standalone) ...[
                        const SizedBox(height: 10),
                        const InfoBanner(
                          text: '单机模式开启中：生成按钮会提示关闭联网。',
                          icon: Icons.flight_takeoff_rounded,
                          color: AppColors.warning,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        ErrorBanner(message: _error!, onRetry: _generate),
                      ],
                      if (_result != null || _summaryText != null) ...[
                        const SizedBox(height: 14),
                        _ResultCard(
                          title: switch (_mode) {
                            'polish' => '整理结果',
                            'rewrite' => '改写候选',
                            'translate' => '$_targetName译文',
                            _ => '摘要与要点',
                          },
                          result: _result ?? '',
                          bullets: _bullets,
                          onApply: _applyText,
                          onCopy: () async {
                            await Clipboard.setData(
                                ClipboardData(text: _result ?? _summaryText ?? ''));
                            if (context.mounted) showToast(context, '已复制结果');
                          },
                        ),
                      ],
                      if (_mode == 'rewrite' && _candidates.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ..._candidates.asMap().entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.accentSoft,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('${entry.key + 1}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.accentDark,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(entry.value,
                                          style: const TextStyle(
                                              fontSize: 13, height: 1.55)),
                                    ),
                                    TextButton(
                                      onPressed: () => setState(
                                          () => _result = entry.value),
                                      style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact),
                                      child: const Text('预览',
                                          style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        '结果来自自建后端。若服务不可达，会显示具体错误与重试按钮；不会伪造成功。',
                        style: TextStyle(fontSize: 10.5, color: secondary, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_useInApp)
            InAppKeyboard(
              host: _host,
              initialMode: 'qwerty',
              showHint: false,
              onEnter: state.enterSend ? () => _generate() : null,
            ),
        ],
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChanged;
  const _ModeTabs({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _modeNames.entries.map((entry) {
        final active = entry.key == mode;
        return ChoiceChip(
          label: Text(entry.value),
          selected: active,
          showCheckmark: false,
          onSelected: (_) => onChanged(entry.key),
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        );
      }).toList(),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String result;
  final List<String> bullets;
  final ValueChanged<String> onApply;
  final VoidCallback onCopy;
  const _ResultCard({
    required this.title,
    required this.result,
    required this.bullets,
    required this.onApply,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: '复制',
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 17),
                visualDensity: VisualDensity.compact,
                color: secondary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            result,
            style: const TextStyle(fontSize: 15, height: 1.65),
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...bullets.map((bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: Icon(Icons.circle, size: 4, color: AppColors.accent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(bullet,
                            style: const TextStyle(fontSize: 12.5, height: 1.55)),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onApply(result),
              icon: const Icon(Icons.input_rounded, size: 18),
              label: const Text('应用到输入框'),
            ),
          ),
        ],
      ),
    );
  }
}
