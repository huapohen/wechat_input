import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'engine.dart';
import 'voice_sheet.dart';

const Map<String, String> kModeNames = {
  't9': '九宫格拼音',
  'qwerty': '全键盘拼音',
  'handwrite': '手写',
  'stroke': '笔画',
  'wubi': '五笔',
  'doublepin': '双拼',
  'english': '英文',
  'number': '数字',
  'symbols': '符号',
  'emoji': '表情',
};

const Map<String, IconData> kModeIcons = {
  't9': Icons.grid_view_rounded,
  'qwerty': Icons.keyboard_rounded,
  'handwrite': Icons.draw_rounded,
  'stroke': Icons.gesture_rounded,
  'wubi': Icons.text_fields_rounded,
  'doublepin': Icons.dialpad_rounded,
  'english': Icons.abc_rounded,
  'number': Icons.pin_rounded,
  'symbols': Icons.tag_rounded,
  'emoji': Icons.emoji_emotions_outlined,
};

const Map<String, IconData> kToolIcons = {
  'switch': Icons.keyboard_alt_outlined,
  'voice': Icons.mic_none_rounded,
  'clipboard': Icons.content_paste_rounded,
  'phrases': Icons.format_quote_rounded,
  'emoji': Icons.emoji_emotions_outlined,
  'handwrite': Icons.draw_rounded,
  'ai': Icons.auto_awesome_rounded,
  'translate': Icons.translate_rounded,
  'polish': Icons.auto_fix_high_rounded,
  'settings': Icons.tune_rounded,
};

const Map<String, String> kToolNames = {
  'switch': '切换键盘',
  'voice': '语音',
  'clipboard': '剪贴板',
  'phrases': '常用语',
  'emoji': '表情',
  'handwrite': '手写找字',
  'ai': '问 AI',
  'translate': '翻译',
  'polish': '文字整理',
  'settings': '键盘设置',
};

class HostTextEditing {
  final TextEditingController controller;
  final FocusNode focusNode;
  HostTextEditing({required this.controller, required this.focusNode});

  TextSelection get _selection {
    final sel = controller.selection;
    if (!sel.isValid) {
      return TextSelection.collapsed(offset: controller.text.length);
    }
    return sel;
  }

  void insert(String value) {
    if (value.isEmpty) return;
    final text = controller.text;
    final sel = _selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    final next = text.replaceRange(start, end, value);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    focusNode.requestFocus();
  }

  void backspace() {
    final text = controller.text;
    final sel = _selection;
    if (!sel.isCollapsed) {
      final next = text.replaceRange(sel.start, sel.end, '');
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      focusNode.requestFocus();
      return;
    }
    final offset = sel.start.clamp(0, text.length);
    if (offset <= 0) return;
    final before = text.substring(0, offset);
    final runes = before.runes.toList();
    if (runes.isEmpty) return;
    final cut = String.fromCharCodes(runes.sublist(0, runes.length - 1)).length;
    final next = text.replaceRange(cut, offset, '');
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cut),
    );
    focusNode.requestFocus();
  }

  void clear() {
    controller.clear();
    focusNode.requestFocus();
  }

  String get text => controller.text;
}

class InAppKeyboard extends StatefulWidget {
  final HostTextEditing host;
  final String initialMode;
  final ValueChanged<String>? onModeChanged;
  final VoidCallback? onEnter;
  final bool showHint;
  const InAppKeyboard({
    super.key,
    required this.host,
    this.initialMode = 't9',
    this.onModeChanged,
    this.onEnter,
    this.showHint = true,
  });

  @override
  State<InAppKeyboard> createState() => InAppKeyboardState();
}

class InAppKeyboardState extends State<InAppKeyboard> {
  KeyboardData? _data;
  String? _loadError;
  late String _mode;
  String _buffer = '';
  List<Candidate> _candidates = const [];
  bool _shift = false;
  bool _caps = false;
  List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  int _emojiCategory = 0;
  bool _busyLoading = false;

  AppState get _state => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busyLoading = true;
      _loadError = null;
    });
    try {
      final data = await KeyboardData.ensureLoaded();
      if (!mounted) return;
      setState(() {
        _data = data;
        _busyLoading = false;
      });
      _refreshCandidates();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '词库加载失败：$e';
        _busyLoading = false;
      });
    }
  }

  String get _modeName => kModeNames[_mode] ?? _mode;

  bool get _isChinese =>
      _mode == 't9' || _mode == 'qwerty' || _mode == 'wubi' || _mode == 'doublepin' || _mode == 'stroke';

  void _refreshCandidates() {
    final data = _data;
    if (data == null) return;
    final state = _state;
    List<Candidate> list = const [];
    switch (_mode) {
      case 't9':
        list = data.t9Candidates(_buffer, state);
      case 'qwerty':
        list = data.pinyinCandidates(_buffer, state);
      case 'wubi':
        list = data.wubiCandidates(_buffer, state);
      case 'stroke':
        list = data.strokeCandidates(_buffer, state);
      case 'doublepin':
        list = data.doublePinCandidates(_buffer, state);
      case 'english':
        list = state.englishAutoCorrect
            ? data.englishSuggestions(_buffer, state)
            : const [];
      case 'handwrite':
        list = data.recognizeStrokes(_strokes, state);
      default:
        list = const [];
    }
    setState(() => _candidates = list);
  }

  void _setMode(String mode) {
    final enabled = _state.enabledModes;
    if (!enabled.contains(mode)) {
      showToast(context, '键盘未启用，请先在「键盘管理」中开启');
      return;
    }
    setState(() {
      _mode = mode;
      _buffer = '';
      _candidates = const [];
      _strokes = [];
      _currentStroke = [];
    });
    _state.setLastMode(mode);
    widget.onModeChanged?.call(mode);
  }

  void _commit(String text, {bool learn = true}) {
    if (text.isEmpty) return;
    var value = text;
    final state = _state;
    final hostText = widget.host.text;
    final sel = widget.host.controller.selection;
    final offset = sel.isValid ? sel.start.clamp(0, hostText.length) : hostText.length;
    if (offset > 0) {
      final prev = hostText.substring(offset - 1, offset);
      final first = text.substring(0, 1);
      final prevChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(prev);
      final firstChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(first);
      final prevLatin = RegExp(r'[A-Za-z]').hasMatch(prev);
      final firstLatin = RegExp(r'[A-Za-z]').hasMatch(first);
      final prevDigit = RegExp(r'[0-9]').hasMatch(prev);
      if (state.autoSpaceAbc && ((firstChinese && prevLatin) || (firstLatin && prevChinese))) {
        value = ' $value';
      } else if (state.autoSpace123 && firstChinese && prevDigit) {
        value = ' $value';
      }
    }
    widget.host.insert(value);
    if (learn) state.learn(text);
    setState(() {
      _buffer = '';
      _candidates = const [];
    });
  }

  void _appendCode(String value) {
    setState(() => _buffer += value);
    _refreshCandidates();
  }

  void _delete() {
    if (_buffer.isNotEmpty) {
      final runes = _buffer.runes.toList();
      setState(() {
        _buffer = String.fromCharCodes(runes.sublist(0, runes.length - 1));
      });
      _refreshCandidates();
      return;
    }
    if (_mode == 'handwrite' && _strokes.isNotEmpty) {
      setState(() => _strokes.removeLast());
      _refreshCandidates();
      return;
    }
    widget.host.backspace();
    if (_mode == 'english' && _buffer.isNotEmpty) {
      final runes = _buffer.runes.toList();
      setState(() => _buffer = String.fromCharCodes(runes.sublist(0, runes.length - 1)));
      _refreshCandidates();
    }
  }

  void _space() {
    if (_isChinese) {
      if (_buffer.isNotEmpty && _candidates.isNotEmpty) {
        _commit(_candidates.first.text);
        return;
      }
      if (_buffer.isNotEmpty) {
        _commit(_buffer, learn: false);
        return;
      }
    }
    if (_state.doubleSpacePeriod) {
      final text = widget.host.text;
      final sel = widget.host.controller.selection;
      final offset = sel.isValid ? sel.start : text.length;
      if (offset > 0 && text.substring(offset - 1, offset) == ' ') {
        final next = text.replaceRange(offset - 1, offset, '。');
        widget.host.controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: offset),
        );
        _playKey();
        return;
      }
    }
    widget.host.insert(' ');
    if (_buffer.isNotEmpty) {
      setState(() => _buffer = '');
      _candidates = const [];
    }
    _playKey();
  }

  void _newline() {
    if (widget.onEnter != null) {
      widget.onEnter!();
    } else {
      widget.host.insert('\n');
    }
    setState(() => _buffer = '');
  }

  void _typeEnglish(String letter) {
    final state = _state;
    final text = widget.host.text;
    final sel = widget.host.controller.selection;
    final offset = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    var autoCap = false;
    if (state.capitalize && offset == 0) {
      autoCap = true;
    } else if (state.capitalize && offset > 0) {
      final prev = text.substring(offset - 1, offset);
      autoCap = '。！？.!?\n'.contains(prev);
    }
    final upper = _shift || _caps || autoCap;
    var value = upper ? letter.toUpperCase() : letter;
    if (state.autoSpaceAbc && offset > 0) {
      final prev = text.substring(offset - 1, offset);
      if (RegExp(r'[\u4e00-\u9fff]').hasMatch(prev)) value = ' $value';
    }
    widget.host.insert(value);
    _shift = false;
    setState(() => _buffer += letter.toLowerCase());
    _refreshCandidates();
  }

  void _playKey() {
    final state = _state;
    if (state.keySound) {
      SystemSound.play(SystemSoundType.click);
    }
    if (state.keyVibrate) {
      if (state.vibrateLevel > .75) {
        HapticFeedback.mediumImpact();
      } else if (state.vibrateLevel > .4) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
  }

  Future<void> _openModeSheet() async {
    final enabled = _state.enabledModes;
    final modes = _state.modeOrder.where(enabled.contains).toList();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择键盘', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('当前输入不会丢失；切换后继续使用同一宿主输入框。',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: modes.map((mode) {
                  final active = mode == _mode;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, mode),
                    child: Container(
                      width: (MediaQuery.sizeOf(context).width - 70) / 2,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: active ? AppColors.accentSoft : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: active ? AppColors.accent : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(kModeIcons[mode] ?? Icons.keyboard,
                              size: 20,
                              color: active ? AppColors.accentDark : AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(kModeNames[mode] ?? mode,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
                          ),
                          if (active)
                            const Icon(Icons.check_circle,
                                size: 17, color: AppColors.accent),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/keyboard/manage');
                },
                icon: const Icon(Icons.settings_suggest_outlined, size: 18),
                label: const Text('管理键盘'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) _setMode(selected);
  }

  Future<void> _openVoice() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => VoiceInputSheet(autoStart: true),
    );
    if (text != null && text.trim().isNotEmpty) {
      _commit(text.trim());
    }
  }

  Future<void> _showClipboard() async {
    final state = _state;
    final items = state.clipboard;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('剪贴板', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('点击插入到输入框',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('暂无历史。复制文本后，打开剪贴板即可记录。')),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(items[index], maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(context);
                        _commit(items[index], learn: false);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPhrases() async {
    final phrases = _state.phrases;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('常用语', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (phrases.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('暂无常用语，可在首页「常用语」中添加。'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: phrases.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(phrases[index].text),
                      subtitle: phrases[index].code.isEmpty ? null : Text(phrases[index].code),
                      onTap: () {
                        Navigator.pop(context);
                        _commit(phrases[index].text);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toolAction(String tool) async {
    switch (tool) {
      case 'switch':
        _openModeSheet();
      case 'voice':
        _openVoice();
      case 'clipboard':
        _showClipboard();
      case 'phrases':
        _showPhrases();
      case 'emoji':
        _setMode('emoji');
      case 'handwrite':
        _setMode('handwrite');
      case 'ai':
        Navigator.pushNamed(context, '/ai', arguments: {'draft': widget.host.text});
      case 'translate':
        Navigator.pushNamed(context, '/translate', arguments: {'text': widget.host.text});
      case 'polish':
        Navigator.pushNamed(context, '/tools',
            arguments: {'text': widget.host.text, 'mode': 'polish'});
      case 'settings':
        _openQuickSettings();
    }
  }

  Future<void> _openQuickSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final state = _state;
          final dark = Theme.of(context).brightness == Brightness.dark;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('键盘快捷设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ToggleRow(
                    title: '按键声音',
                    value: state.keySound,
                    onChanged: (v) async {
                      await state.setFlag('keys.sound', v);
                      setSheetState(() {});
                    },
                  ),
                  ToggleRow(
                    title: '按键振动',
                    value: state.keyVibrate,
                    onChanged: (v) async {
                      await state.setFlag('keys.vibrate', v);
                      setSheetState(() {});
                    },
                  ),
                  ToggleRow(
                    title: '按键气泡',
                    value: state.keyBubble,
                    onChanged: (v) async {
                      await state.setFlag('keys.bubble', v);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('候选字大小', style: TextStyle(fontSize: 13, color: dark ? AppColors.darkSecondary : AppColors.textSecondary)),
                  Slider(
                    value: state.candidateSize,
                    min: 14,
                    max: 26,
                    divisions: 12,
                    label: state.candidateSize.round().toString(),
                    onChanged: (v) async {
                      await state.setCandidateSize(v);
                      setSheetState(() {});
                      this.setState(() {});
                    },
                  ),
                  Text('键盘高度', style: TextStyle(fontSize: 13, color: dark ? AppColors.darkSecondary : AppColors.textSecondary)),
                  Slider(
                    value: state.keyboardScale,
                    min: .75,
                    max: 1.35,
                    divisions: 12,
                    label: '${(state.keyboardScale * 100).round()}%',
                    onChanged: (v) async {
                      await state.setKeyboardScale(v);
                      setSheetState(() {});
                      this.setState(() {});
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/settings/display');
                          },
                          child: const Text('布局和显示'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/settings/keystroke');
                          },
                          child: const Text('按键效果'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _fixCandidate(Candidate candidate) {
    final code = _buffer.trim();
    if (code.isEmpty) {
      showToast(context, '请先输入编码');
      return;
    }
    _state.fixWord(code, candidate.text);
    showToast(context, '已固定「${candidate.text}」到候选首位');
  }

  Future<void> _deleteCandidate(Candidate candidate) async {
    final ok = await confirmAction(
      context,
      title: '删除候选',
      message: '从本机词库删除「${candidate.text}」？你可以随时在「辅助输入」中恢复个人词典。',
      confirm: '删除',
      danger: true,
    );
    if (!ok) return;
    await _state.deleteWord(candidate.text);
    _refreshCandidates();
  }

  void _candidateLongPress(Candidate candidate) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('固定到候选首位'),
              subtitle: Text(_buffer.isEmpty ? '' : '编码：$_buffer'),
              onTap: () {
                Navigator.pop(context);
                _fixCandidate(candidate);
                _refreshCandidates();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('删除该候选', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                _deleteCandidate(candidate);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  double _totalHeight(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final base = wide ? 338.0 : 300.0;
    final toolbar = _state.showToolbar ? 40.0 : 0.0;
    return base * _state.keyboardScale + 50 + toolbar + 12;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppPalette(dark);
    final height = _totalHeight(context);
    final enabled = state.enabledModes;
    if (!enabled.contains(_mode)) {
      _mode = enabled.isEmpty ? 't9' : enabled.first;
    }
    final toolbarOrder = state.toolbarOrder
        .where((e) => !state.toolbarHidden.contains(e))
        .where((e) => e != 'voice' || state.showVoiceIcon)
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: palette.keyboard,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: SizedBox(
              height: height,
              child: Column(
                children: [
                  if (state.showToolbar)
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              itemCount: toolbarOrder.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 2),
                              itemBuilder: (context, index) {
                                final tool = toolbarOrder[index];
                                return _ToolButton(
                                  icon: kToolIcons[tool] ?? Icons.circle_outlined,
                                  label: kToolNames[tool] ?? tool,
                                  onTap: () => _toolAction(tool),
                                );
                              },
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openModeSheet,
                            icon: Icon(kModeIcons[_mode] ?? Icons.keyboard, size: 16),
                            label: Text(_modeName, style: const TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: palette.secondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  _CandidateBar(
                    mode: _mode,
                    modeName: _modeName,
                    buffer: _buffer,
                    candidates: _candidates,
                    fontSize: state.candidateSize,
                    data: _data,
                    onPick: (candidate) {
                      if (_mode == 'english') {
                        widget.host.insert(candidate.text.substring(
                            math.min(_buffer.length, candidate.text.length)));
                        _state.learn(candidate.text);
                        setState(() {
                          _buffer = '';
                          _candidates = const [];
                        });
                      } else {
                        _commit(candidate.text);
                      }
                    },
                    onLongPress: _candidateLongPress,
                    onDelete: _delete,
                    onHint: _loadError != null ? _load : null,
                    loadError: _loadError,
                    loading: _busyLoading,
                  ),
                  Expanded(
                    child: Builder(builder: (context) {
                      final split = state.splitKeyboard &&
                          MediaQuery.sizeOf(context).width >= 720;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(split ? 42 : 6, 3, split ? 42 : 6, 6),
                        child: Stack(
                          children: [
                            Positioned.fill(child: _buildBody(context, state)),
                            if (split)
                              Center(
                                child: Container(
                                  width: 1,
                                  height: double.infinity,
                                  color: palette.border.withValues(alpha: .6),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppState state) {
    switch (_mode) {
      case 't9':
        return _t9Layout(context);
      case 'qwerty':
        return _qwertyLayout(context, codeMode: true);
      case 'wubi':
        return _qwertyLayout(context, codeMode: true);
      case 'doublepin':
        return _qwertyLayout(context, codeMode: true);
      case 'english':
        return _englishLayout(context);
      case 'number':
        return _numberLayout(context);
      case 'symbols':
        return _symbolsLayout(context);
      case 'emoji':
        return _emojiLayout(context);
      case 'stroke':
        return _strokeLayout(context);
      case 'handwrite':
        return _handwriteLayout(context);
      default:
        return _qwertyLayout(context, codeMode: false);
    }
  }

  Widget _row(List<Widget> children, {double gap = 5, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _key(
    String label, {
    String? sub,
    IconData? icon,
    int flex = 1,
    bool special = false,
    bool accent = false,
    double? fontSize,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool enabled = true,
  }) {
    return _KbKey(
      label: label,
      sub: sub,
      icon: icon,
      flex: flex,
      special: special,
      accent: accent,
      fontSize: fontSize,
      enabled: enabled,
      bubble: _state.keyBubble,
      onTap: enabled
          ? () {
              _playKey();
              onTap?.call();
            }
          : null,
      onLongPress: onLongPress,
    );
  }

  Widget _t9Layout(BuildContext context) {
    return Column(
      children: [
        _row([
          _key('1', sub: '。，', onTap: () => _appendCode('1')),
          _key('2', sub: 'ABC', onTap: () => _appendCode('2')),
          _key('3', sub: 'DEF', onTap: () => _appendCode('3')),
          _key('', icon: Icons.backspace_outlined, special: true, onTap: _delete),
        ]),
        _row([
          _key('4', sub: 'GHI', onTap: () => _appendCode('4')),
          _key('5', sub: 'JKL', onTap: () => _appendCode('5')),
          _key('6', sub: 'MNO', onTap: () => _appendCode('6')),
          _key('', icon: Icons.keyboard_return_rounded, special: true, onTap: _newline),
        ]),
        _row([
          _key('7', sub: 'PQRS', onTap: () => _appendCode('7')),
          _key('8', sub: 'TUV', onTap: () => _appendCode('8')),
          _key('9', sub: 'WXYZ', onTap: () => _appendCode('9')),
          _key('', icon: Icons.space_bar_rounded, special: true, flex: 1, onTap: _space),
        ]),
        _row([
          _key('符号', special: true, fontSize: 13, onTap: () => _setMode('symbols')),
          _key('0', onTap: () => _appendCode('0')),
          _key('空格', special: true, flex: 2, fontSize: 13, onTap: _space,
              onLongPress: _state.longPressSpaceVoice ? _openVoice : null),
          if (_state.showEmojiKey)
            _key('😊', special: true, fontSize: 16, onTap: () => _setMode('emoji')),
          _key('中/英', special: true, fontSize: 13, onTap: _toggleLanguage),
        ]),
      ],
    );
  }

  void _toggleLanguage() {
    if (_mode == 'english' || _mode == 'number' || _mode == 'symbols' || _mode == 'emoji') {
      _setMode(_preferredChineseMode());
    } else {
      _setMode('english');
    }
  }

  String _preferredChineseMode() {
    final enabled = _state.enabledModes;
    for (final mode in ['t9', 'qwerty', 'wubi', 'doublepin']) {
      if (enabled.contains(mode)) return mode;
    }
    return 't9';
  }

  Widget _qwertyLayout(BuildContext context, {required bool codeMode}) {
    final letters = 'qwertyuiop'.split('');
    final middle = 'asdfghjkl'.split('');
    final bottom = 'zxcvbnm'.split('');
    return Column(
      children: [
        _row(letters.map((l) => _key(_shift || _caps ? l.toUpperCase() : l,
            onTap: () => _appendCode(l))).toList(),
            gap: 4),
        _row([
          const SizedBox(width: 12),
          ...middle.map((l) => _key(_shift || _caps ? l.toUpperCase() : l,
              onTap: () => _appendCode(l))),
          const SizedBox(width: 12),
        ], gap: 4),
        _row([
          _key('', icon: _caps
              ? Icons.keyboard_capslock_rounded
              : Icons.arrow_upward_rounded,
              special: true, flex: 2, onTap: () {
            setState(() {
              if (_shift) {
                _shift = false;
                _caps = !_caps;
              } else {
                _shift = true;
              }
            });
          }),
          ...bottom.map((l) => _key(_shift || _caps ? l.toUpperCase() : l,
              onTap: () => _appendCode(l))),
          _key('', icon: Icons.backspace_outlined, special: true, flex: 2, onTap: _delete),
        ], gap: 4),
        _row([
          _key('123', special: true, fontSize: 13, onTap: () => _setMode('number')),
          _key('中/英', special: true, fontSize: 13, onTap: _toggleLanguage),
          if (_state.showEmojiKey)
            _key('😊', special: true, fontSize: 16, onTap: () => _setMode('emoji')),
          _key('，', special: true, onTap: () => _commit('，')),
          _key('空格', special: true, flex: 4, fontSize: 14, onTap: _space,
              onLongPress: _state.longPressSpaceVoice ? _openVoice : null),
          _key('。', special: true, onTap: () => _commit('。')),
          _key('', icon: Icons.keyboard_return_rounded, special: true, flex: 2, onTap: _newline),
        ], gap: 4),
      ],
    );
  }

  Widget _englishLayout(BuildContext context) {
    final letters = 'qwertyuiop'.split('');
    final middle = 'asdfghjkl'.split('');
    final bottom = 'zxcvbnm'.split('');
    return Column(
      children: [
        _row(letters.map((l) => _key(_shift || _caps ? l.toUpperCase() : l,
            onTap: () => _typeEnglish(l))).toList(), gap: 4),
        _row([
          const SizedBox(width: 14),
          ...middle.map((l) => _key(_shift || _caps ? l.toUpperCase() : l,
              onTap: () => _typeEnglish(l))),
          const SizedBox(width: 14),
        ], gap: 4),
        _row([
          _key('', icon: _caps ? Icons.keyboard_capslock_rounded : Icons.arrow_upward_rounded,
              special: true, flex: 2, onTap: () {
            setState(() {
              if (_shift) {
                _shift = false;
                _caps = !_caps;
              } else {
                _shift = true;
              }
            });
          }),
          ...bottom.map((l) => _key(_shift || _caps ? l.toUpperCase() : l,
              onTap: () => _typeEnglish(l))),
          _key('', icon: Icons.backspace_outlined, special: true, flex: 2, onTap: _delete),
        ], gap: 4),
        _row([
          _key('123', special: true, fontSize: 13, onTap: () => _setMode('number')),
          _key('中/英', special: true, fontSize: 13, onTap: _toggleLanguage),
          if (_state.showEmojiKey)
            _key('😊', special: true, fontSize: 16, onTap: () => _setMode('emoji')),
          _key(',', special: true, onTap: () => widget.host.insert(', ')),
          _key('space', special: true, flex: 4, fontSize: 13, onTap: _space,
              onLongPress: _state.longPressSpaceVoice ? _openVoice : null),
          _key('.', special: true, onTap: () => widget.host.insert('. ')),
          _key('', icon: Icons.keyboard_return_rounded, special: true, flex: 2, onTap: _newline),
        ], gap: 4),
      ],
    );
  }

  Widget _numberLayout(BuildContext context) {
    Widget n(String value) => _key(value,
        fontSize: _state.numberLayout == 'grid' ? 22 : 18,
        onTap: () => widget.host.insert(value));
    if (_state.numberLayout == 'row') {
      return Column(
        children: [
          _row([
            for (final digit in const ['1','2','3','4','5','6','7','8','9','0'])
              n(digit),
          ], gap: 3),
          _row([
            _key('-', special: true, onTap: () => widget.host.insert('-')),
            _key('+', special: true, onTap: () => widget.host.insert('+')),
            _key('×', special: true, onTap: () => widget.host.insert('×')),
            _key('÷', special: true, onTap: () => widget.host.insert('÷')),
            _key('=', special: true, onTap: () => widget.host.insert('=')),
            _key('.', special: true, onTap: () => widget.host.insert('.')),
            _key('', icon: Icons.backspace_outlined, special: true, onTap: _delete),
          ], gap: 3),
          _row([
            _key('符号', special: true, fontSize: 13, onTap: () => _setMode('symbols')),
            _key('中/英', special: true, fontSize: 13, onTap: _toggleLanguage),
            _key('空格', special: true, flex: 4, fontSize: 13, onTap: _space),
            _key('清空', special: true, fontSize: 13, onTap: widget.host.clear),
            _key('', icon: Icons.keyboard_return_rounded, special: true, onTap: _newline),
          ], gap: 3),
        ],
      );
    }
    return Column(
      children: [
        _row([n('1'), n('2'), n('3'), _key('', icon: Icons.backspace_outlined, special: true, onTap: _delete)]),
        _row([n('4'), n('5'), n('6'), _key('', icon: Icons.keyboard_return_rounded, special: true, onTap: _newline)]),
        _row([n('7'), n('8'), n('9'), _key('-', special: true, onTap: () => widget.host.insert('-'))]),
        _row([
          _key('.', special: true, onTap: () => widget.host.insert('.')),
          n('0'),
          _key('+', special: true, onTap: () => widget.host.insert('+')),
          _key('符号', special: true, fontSize: 13, onTap: () => _setMode('symbols')),
        ]),
        _row([
          _key('中/英', special: true, fontSize: 13, onTap: _toggleLanguage),
          _key('空格', special: true, flex: 3, fontSize: 13, onTap: _space),
          _key('清空', special: true, fontSize: 13, onTap: widget.host.clear),
        ]),
      ],
    );
  }

  Widget _symbolsLayout(BuildContext context) {
    final items = KeyboardData.punctuation;
    final rows = <Widget>[];
    const perRow = 7;
    for (var i = 0; i < items.length; i += perRow) {
      final slice = items.skip(i).take(perRow).toList();
      rows.add(_row(slice
          .map((symbol) => _key(symbol,
              fontSize: 18, onTap: () => widget.host.insert(symbol)))
          .toList()));
    }
    rows.add(_row([
      _key('123', special: true, fontSize: 13, onTap: () => _setMode('number')),
      _key('中/英', special: true, fontSize: 13, onTap: _toggleLanguage),
      _key('空格', special: true, flex: 3, fontSize: 13, onTap: _space,
          onLongPress: _state.longPressSpaceVoice ? _openVoice : null),
      _key('', icon: Icons.backspace_outlined, special: true, onTap: _delete),
      _key('', icon: Icons.keyboard_return_rounded, special: true, onTap: _newline),
    ]));
    return Column(children: rows);
  }

  Widget _emojiLayout(BuildContext context) {
    final data = _data;
    if (data == null || data.emoji.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final categories = data.emoji;
    final index = _emojiCategory.clamp(0, categories.length - 1);
    final items = categories[index].items;
    return Column(
      children: [
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) => ChoiceChip(
              label: Text(categories[i].name),
              selected: i == index,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                  fontSize: 11.5,
                  color: i == index ? AppColors.accentDark : null,
                  fontWeight: i == index ? FontWeight.w600 : FontWeight.w400),
              onSelected: (_) => setState(() => _emojiCategory = i),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 9,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                _playKey();
                widget.host.insert(items[i]);
              },
              child: Center(
                child: Text(items[i], style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              _key('中/英', special: true, fontSize: 13, onTap: _toggleLanguage),
              const SizedBox(width: 5),
              _key('空格', special: true, flex: 3, fontSize: 13, onTap: _space),
              const SizedBox(width: 5),
              _key('', icon: Icons.backspace_outlined, special: true, onTap: _delete),
            ],
          ),
        ),
      ],
    );
  }

  Widget _strokeLayout(BuildContext context) {
    final strokes = [
      ('一', 'h'),
      ('丨', 's'),
      ('丿', 'p'),
      ('丶', 'n'),
      ('乛', 'z'),
      ('?', '?'),
    ];
    return Column(
      children: [
        _row(strokes.map((e) => _key(e.$1,
            sub: e.$2,
            fontSize: 20,
            onTap: () => _appendCode(e.$2))).toList()),
        _row([
          _key('符号', special: true, fontSize: 13, onTap: () => _setMode('symbols')),
          _key('', icon: Icons.backspace_outlined, special: true, onTap: _delete),
          _key('中/英', special: true, fontSize: 13, onTap: _toggleLanguage),
        ]),
        _row([
          _key('空格', special: true, flex: 4, fontSize: 13, onTap: _space,
              onLongPress: _state.longPressSpaceVoice ? _openVoice : null),
          _key('', icon: Icons.keyboard_return_rounded, special: true, onTap: _newline),
        ]),
      ],
    );
  }

  Widget _handwriteLayout(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.draw_rounded, size: 16,
                  color: dark ? AppColors.darkSecondary : AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '在下方书写，按笔画方向做轻量模板匹配（常用字演示）',
                  style: TextStyle(
                      fontSize: 11,
                      color: dark ? AppColors.darkSecondary : AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _strokes = [];
                    _currentStroke = [];
                    _candidates = const [];
                  });
                },
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: _strokes.isEmpty
                    ? null
                    : () {
                        setState(() => _strokes.removeLast());
                        _refreshCandidates();
                      },
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('撤销', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? AppColors.darkBorder : AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  setState(() => _currentStroke = [details.localPosition]);
                },
                onPanUpdate: (details) {
                  setState(() => _currentStroke = [..._currentStroke, details.localPosition]);
                },
                onPanEnd: (details) {
                  if (_currentStroke.length < 2) return;
                  setState(() {
                    _strokes = [..._strokes, _currentStroke];
                    _currentStroke = [];
                  });
                  _refreshCandidates();
                },
                child: CustomPaint(
                  painter: _StrokePainter(
                    strokes: _strokes,
                    current: _currentStroke,
                    color: dark ? AppColors.darkText : AppColors.text,
                    guide: dark ? AppColors.darkBorder : AppColors.border,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 42,
          child: Row(
            children: [
              _key('切换', special: true, fontSize: 12, onTap: _openModeSheet),
              const SizedBox(width: 5),
              _key('删除', special: true, fontSize: 12, onTap: _delete),
              const SizedBox(width: 5),
              _key('空格', special: true, flex: 3, fontSize: 13, onTap: _space),
              const SizedBox(width: 5),
              _key('', icon: Icons.keyboard_return_rounded, special: true, onTap: _newline),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSecondary
        : AppColors.textSecondary;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: secondary),
              const SizedBox(height: 1),
              Text(label,
                  style: TextStyle(fontSize: 9, color: secondary, height: 1),
                  maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateBar extends StatelessWidget {
  final String mode;
  final String modeName;
  final String buffer;
  final List<Candidate> candidates;
  final double fontSize;
  final KeyboardData? data;
  final ValueChanged<Candidate> onPick;
  final ValueChanged<Candidate> onLongPress;
  final VoidCallback onDelete;
  final VoidCallback? onHint;
  final String? loadError;
  final bool loading;

  const _CandidateBar({
    required this.mode,
    required this.modeName,
    required this.buffer,
    required this.candidates,
    required this.fontSize,
    required this.data,
    required this.onPick,
    required this.onLongPress,
    required this.onDelete,
    this.onHint,
    this.loadError,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final specialMode = mode == 'number' || mode == 'symbols' || mode == 'emoji';
    return SizedBox(
      height: 50,
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: dark ? AppColors.darkSurface : AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mode == 'doublepin' && buffer.isNotEmpty
                          ? '${data?.decodeDoublePin(buffer) ?? ''} · $modeName'
                          : specialMode
                              ? modeName
                              : buffer.isEmpty
                                  ? modeName
                                  : '$buffer · $modeName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: secondary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2)))
                        : loadError != null
                            ? InkWell(
                                onTap: onHint,
                                child: Center(
                                  child: Text('词库加载失败，点击重试',
                                      style: TextStyle(fontSize: 11, color: AppColors.danger)),
                                ),
                              )
                            : candidates.isEmpty
                                ? Center(
                                    child: Text(
                                      buffer.isEmpty
                                          ? (mode == 'handwrite' ? '书写后在此选字' : '候选将在这里出现')
                                          : '无候选，空格上屏编码',
                                      style: TextStyle(fontSize: 11.5, color: secondary),
                                    ),
                                  )
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    itemCount: candidates.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 2),
                                    itemBuilder: (context, index) {
                                      final candidate = candidates[index];
                                      final first = index == 0 && buffer.isNotEmpty;
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => onPick(candidate),
                                        onLongPress: () => onLongPress(candidate),
                                        child: Container(
                                          constraints: const BoxConstraints(minWidth: 38),
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(horizontal: 9),
                                          decoration: BoxDecoration(
                                            color: first
                                                ? AppColors.accent.withValues(alpha: .14)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            candidate.text,
                                            style: TextStyle(
                                              fontSize: fontSize,
                                              fontWeight: first ? FontWeight.w600 : FontWeight.w500,
                                              color: first
                                                  ? (dark ? AppColors.accent : AppColors.accentDark)
                                                  : (dark ? AppColors.darkText : AppColors.text),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.backspace_outlined, size: 18),
                    color: secondary,
                    visualDensity: VisualDensity.compact,
                    tooltip: '删除',
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 7,
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : AppColors.surface,
              border: Border(
                bottom: BorderSide(color: dark ? AppColors.darkBorder : AppColors.border),
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 44,
              height: 3,
              decoration: BoxDecoration(
                color: secondary.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KbKey extends StatefulWidget {
  final String label;
  final String? sub;
  final IconData? icon;
  final int flex;
  final bool special;
  final bool accent;
  final double? fontSize;
  final bool enabled;
  final bool bubble;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _KbKey({
    required this.label,
    this.sub,
    this.icon,
    this.flex = 1,
    this.special = false,
    this.accent = false,
    this.fontSize,
    this.enabled = true,
    this.bubble = true,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_KbKey> createState() => _KbKeyState();
}

class _KbKeyState extends State<_KbKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppPalette(dark);
    final bg = widget.accent
        ? AppColors.accent
        : widget.special
            ? palette.keySpecial
            : palette.key;
    final fg = widget.accent
        ? Colors.white
        : widget.enabled
            ? palette.text
            : palette.secondary.withValues(alpha: .5);
    final scale = _pressed && widget.bubble ? 1.035 : 1.0;
    return Expanded(
      flex: widget.flex,
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 60),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            decoration: BoxDecoration(
              color: _pressed ? palette.keyPressed : bg,
              borderRadius: BorderRadius.circular(AppTheme.keyRadius),
              border: Border.all(color: palette.border),
              boxShadow: _pressed
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? .12 : .045),
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: widget.icon != null
                ? Icon(widget.icon, size: 20, color: fg)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: widget.fontSize ?? 19,
                          fontWeight: FontWeight.w500,
                          color: fg,
                          height: 1.05,
                        ),
                      ),
                      if (widget.sub != null)
                        Text(
                          widget.sub!,
                          style: TextStyle(
                            fontSize: 8.5,
                            color: fg.withValues(alpha: .6),
                            height: 1.1,
                            letterSpacing: .5,
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

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> current;
  final Color color;
  final Color guide;
  _StrokePainter({
    required this.strokes,
    required this.current,
    required this.color,
    required this.guide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = guide.withValues(alpha: .5)
      ..strokeWidth = .8;
    canvas.drawLine(Offset(size.width / 2, 8), Offset(size.width / 2, size.height - 8), grid);
    canvas.drawLine(Offset(8, size.height / 2), Offset(size.width - 8, size.height / 2), grid);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    void drawStroke(List<Offset> points) {
      if (points.length < 2) return;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }
    drawStroke(current);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
