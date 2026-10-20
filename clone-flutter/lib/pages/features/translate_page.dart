import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../keyboard/keyboard.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class TranslatePage extends StatefulWidget {
  final String initialText;
  const TranslatePage({super.key, this.initialText = ''});

  @override
  State<TranslatePage> createState() => _TranslatePageState();
}

class _TranslatePageState extends State<TranslatePage> {
  final TextEditingController _source = TextEditingController();
  final TextEditingController _target = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final HostTextEditing _host;
  Timer? _debounce;
  int _sequence = 0;
  bool _enabled = true;
  bool _loading = false;
  bool _useInApp = false;
  String? _error;
  String _targetLang = 'en';
  String _status = '输入后自动翻译（600ms 防抖）';
  bool _suppress = false;

  AppState get _state => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    _host = HostTextEditing(controller: _source, focusNode: _focus);
    _source.text = widget.initialText;
    _source.addListener(_onSourceChanged);
    if (_source.text.trim().isNotEmpty) _schedule();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _source.removeListener(_onSourceChanged);
    _source.dispose();
    _target.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onSourceChanged() {
    if (!mounted || _suppress) return;
    _sequence++;
    setState(() {});
    if (_enabled) _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    if (_source.text.trim().isEmpty) {
      _sequence++;
      setState(() {
        _target.clear();
        _status = '等待输入';
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), _translate);
  }

  Future<void> _translate() async {
    final text = _source.text.trim();
    if (text.isEmpty) return;
    if (_state.standalone) {
      setState(() => _error = '单机模式已开启，翻译不可用。');
      return;
    }
    final seq = ++_sequence;
    setState(() {
      _loading = true;
      _error = null;
      _status = '正在翻译…';
    });
    try {
      final result = await ApiClient.fromState(_state)
          .translate(text, target: _targetLang);
      if (!mounted || seq != _sequence) return;
      setState(() {
        _target.text = result;
        _status = '已翻译 · ${text.length} 字符';
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _sequence) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _status = '翻译失败';
      });
    } catch (e) {
      if (!mounted || seq != _sequence) return;
      setState(() {
        _error = '翻译失败：$e';
        _loading = false;
        _status = '翻译失败';
      });
    }
  }

  void _stop() {
    _sequence++;
    _debounce?.cancel();
    setState(() {
      _loading = false;
      _status = '已取消本轮（忽略迟到的响应）';
    });
  }

  void _applyToHost() {
    if (_target.text.trim().isEmpty) return;
    _suppress = true;
    setState(() {
      _source.text = _target.text;
      _source.selection = TextSelection.collapsed(offset: _source.text.length);
      _target.clear();
      _status = '译文已应用到输入框，本轮结束';
    });
    _suppress = false;
    _sequence++;
    if (_useInApp) _focus.requestFocus();
  }

  void _clearRound() {
    _debounce?.cancel();
    _sequence++;
    _suppress = true;
    setState(() {
      _source.clear();
      _target.clear();
      _error = null;
      _loading = false;
      _status = '本轮已清空';
    });
    _suppress = false;
    if (_useInApp) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return Scaffold(
      resizeToAvoidBottomInset: !_useInApp,
      appBar: AppBar(
        title: const Text('边写边译'),
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
          IconButton(
            tooltip: '服务设置',
            onPressed: () => Navigator.pushNamed(context, '/settings/service'),
            icon: const Icon(Icons.tune_rounded, size: 20),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: _enabled
                                  ? AppColors.accentSoft
                                  : secondary.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(_enabled ? '边写边译已开启' : '已暂停',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: _enabled ? AppColors.accentDark : secondary)),
                          ),
                          const Spacer(),
                          Text(_status, style: TextStyle(fontSize: 10.5, color: secondary)),
                          const SizedBox(width: 8),
                          Switch(
                            value: _enabled,
                            onChanged: (v) {
                              setState(() {
                                _enabled = v;
                                if (!v) _debounce?.cancel();
                                _status = v ? '已开启，输入后自动翻译' : '已暂停自动翻译';
                              });
                              if (v) _schedule();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_useInApp ? '源文本 · 内置键盘' : '源文本',
                                    style: TextStyle(fontSize: 11, color: secondary)),
                                const Spacer(),
                                Text('${_source.text.length} 字符',
                                    style: TextStyle(fontSize: 10.5, color: secondary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _source,
                              focusNode: _focus,
                              readOnly: _useInApp,
                              minLines: 4,
                              maxLines: 7,
                              style: const TextStyle(fontSize: 15, height: 1.6),
                              decoration: InputDecoration(
                                hintText: '输入中文、英文或任意语言…',
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
                      const SizedBox(height: 10),
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.translate_rounded,
                                    size: 15, color: AppColors.accentDark),
                                const SizedBox(width: 5),
                                Text('译文 · ${_targetName(_targetLang)}',
                                    style: TextStyle(fontSize: 11, color: secondary)),
                                const Spacer(),
                                if (_loading)
                                  const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(strokeWidth: 2)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 96),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: dark
                                    ? AppColors.darkSurfaceAlt
                                    : AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: SelectableText(
                                _target.text.isEmpty ? '译文会在这里出现' : _target.text,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.65,
                                  color: _target.text.isEmpty
                                      ? secondary.withValues(alpha: .65)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SettingCard(
                        title: '目标语言',
                        description: '切换语言会立即重新翻译；源语言自动识别。',
                        child: SegmentedChoice<String>(
                          value: _targetLang,
                          options: const [
                            MapEntry('en', 'English'),
                            MapEntry('zh', '中文'),
                            MapEntry('ja', '日本語'),
                            MapEntry('ko', '한국어'),
                          ],
                          onChanged: (v) {
                            setState(() => _targetLang = v);
                            _translate();
                          },
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        ErrorBanner(message: _error!, onRetry: _translate),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _target.text.isEmpty ? null : _applyToHost,
                              icon: const Icon(Icons.input_rounded, size: 18),
                              label: const Text('应用到输入框'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: '复制译文',
                            onPressed: _target.text.isEmpty
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: _target.text));
                                    if (context.mounted) showToast(context, '译文已复制');
                                  },
                            icon: const Icon(Icons.copy_rounded, size: 19),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: '取消本轮',
                            onPressed: _stop,
                            icon: const Icon(Icons.stop_circle_outlined, size: 19),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: '清空本轮',
                            onPressed: _clearRound,
                            icon: const Icon(Icons.refresh_rounded, size: 19),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InfoBanner(
                        text: '防抖 600ms，只接受最新一次请求的结果；应用后清空本轮但保持模式。服务不可达时会显示错误，不会显示假译文。',
                        icon: Icons.info_outline_rounded,
                      ),
                      if (state.standalone) ...[
                        const SizedBox(height: 8),
                        const InfoBanner(
                          text: '单机模式开启：翻译请求会被拒绝。',
                          icon: Icons.flight_takeoff_rounded,
                          color: AppColors.warning,
                        ),
                      ],
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
              onEnter: () => _translate(),
            ),
        ],
      ),
    );
  }

  String _targetName(String code) =>
      const {'en': 'English', 'zh': '中文', 'ja': '日本語', 'ko': '한국어'}[code] ?? code;
}
