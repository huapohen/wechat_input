import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _transcript = TextEditingController();
  Timer? _timer;
  bool _initialized = false;
  bool _available = false;
  bool _recording = false;
  bool _paused = false;
  bool _keepListening = false;
  bool _restarting = false;
  int _seconds = 0;
  String? _error;
  String? _speechStatus;
  String? _summary;
  List<String> _bullets = const [];
  bool _summaryLoading = false;
  String? _savedId;

  AppState get _state => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _keepListening = false;
    _speech.stop();
    _transcript.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _error = null;
      _speechStatus = '正在初始化…';
    });
    try {
      final available = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          if (!mounted) return;
          setState(() {
            _error = '识别错误：${error.errorMsg}';
            if (error.permanent) _keepListening = false;
          });
        },
        onStatus: _onStatus,
        debugLogging: false,
      );
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _available = available;
        _speechStatus = available ? '系统语音识别可用' : '系统语音识别不可用';
        if (!available) {
          _error = '当前设备没有可用的语音识别服务。你可以在下方手动输入转写内容，再生成 AI 纪要。';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _available = false;
        _speechStatus = '不可用';
        _error = '语音初始化失败：$e';
      });
    }
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == 'listening') {
      setState(() => _speechStatus = '正在录音并转写…');
    } else if (status == 'done' || status == 'notListening') {
      setState(() => _speechStatus = '识别暂停');
      if (_keepListening && _recording && !_paused && _available && !_restarting) {
        _restarting = true;
        Future.delayed(const Duration(milliseconds: 400), () async {
          _restarting = false;
          if (mounted && _keepListening && !_paused && !_speech.isListening) {
            await _listen();
          }
        });
      }
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _transcript.text = result.recognizedWords;
      _transcript.selection =
          TextSelection.collapsed(offset: _transcript.text.length);
    });
  }

  Future<void> _listen() async {
    if (!_available) {
      if (!_initialized) await _initialize();
      if (!_available) return;
    }
    _keepListening = true;
    try {
      await _speech.listen(
        onResult: _onResult,
        localeId: _state.voiceLanguage,
        listenFor: const Duration(minutes: 2),
        pauseFor: _state.standby == 'never'
            ? const Duration(minutes: 10)
            : Duration(seconds: int.tryParse(_state.standby) ?? 10),
        partialResults: true,
        cancelOnError: false,
        onDevice: _state.offlineSpeech,
      );
    } catch (e) {
      setState(() => _error = '无法开始识别：$e');
    }
  }

  void _start() async {
    if (!_available) {
      await _initialize();
      if (!_available) return;
    }
    setState(() {
      _recording = true;
      _paused = false;
      _seconds = 0;
      _summary = null;
      _bullets = const [];
      _savedId = null;
      _error = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    await _listen();
  }

  Future<void> _pause() async {
    _keepListening = false;
    _timer?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _paused = true;
        _speechStatus = '已暂停';
      });
    }
  }

  Future<void> _resume() async {
    setState(() {
      _paused = false;
      _recording = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    await _listen();
  }

  Future<void> _stop() async {
    _keepListening = false;
    _timer?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recording = false;
      _paused = false;
      _speechStatus = '录音结束';
    });
    if (_transcript.text.trim().isNotEmpty) {
      await _save(auto: true);
    }
  }

  Future<void> _save({bool auto = false}) async {
    final text = _transcript.text.trim();
    if (text.isEmpty) {
      if (!auto) showToast(context, '没有可保存的转写内容');
      return;
    }
    final state = _state;
    final now = DateTime.now();
    final firstLine = text.split('\n').first.trim();
    final id = _savedId ?? now.microsecondsSinceEpoch.toString();
    final title = firstLine.length > 16 ? '${firstLine.substring(0, 16)}…' : firstLine;
    final session = RecorderSession(
      id: id,
      title: title.isEmpty ? '录音' : title,
      transcript: text,
      summary: _summary ?? '',
      durationSeconds: _seconds,
      createdAt: now,
    );
    await state.saveSession(session);
    if (!mounted) return;
    setState(() => _savedId = id);
    if (!auto) showToast(context, '已保存到本机录音会话');
  }

  Future<void> _summarize() async {
    final text = _transcript.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请先录音或输入转写文本');
      return;
    }
    final state = _state;
    if (state.standalone) {
      setState(() => _error = '单机模式已开启，AI 纪要不可用。');
      return;
    }
    setState(() {
      _summaryLoading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.fromState(state).summarize(text);
      final summary = (data['text'] ?? data['summary'] ?? '').toString();
      final bullets = data['bullets'];
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _bullets = bullets is List
            ? bullets.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
            : const [];
      });
      if (_savedId == null) await _save(auto: true);
      final id = _savedId;
      if (id != null) {
        final existing = state.sessions.where((e) => e.id == id).toList();
        if (existing.isNotEmpty) {
          await state.saveSession(existing.first.copyWith(summary: summary));
        }
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '生成纪要失败：$e');
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final active = _recording && !_paused;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 录音笔'),
        actions: [
          IconButton(
            tooltip: '录音会话',
            onPressed: () => Navigator.pushNamed(context, '/recorder/session'),
            icon: const Icon(Icons.library_music_outlined, size: 21),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: () => Navigator.pushNamed(context, '/settings/voice'),
            icon: const Icon(Icons.tune_rounded, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: active
                            ? [const Color(0xFF1FBE8E), const Color(0xFF0E8A68)]
                            : [const Color(0xFFDFF6EC), const Color(0xFFEAF8F3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? Colors.white
                                    : (_available ? AppColors.accent : AppColors.muted),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              active
                                  ? '录音中 · 实时转写'
                                  : _paused
                                      ? '已暂停'
                                      : _available
                                          ? '准备就绪'
                                          : '语音不可用',
                              style: TextStyle(
                                fontSize: 11,
                                color: active ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _speechStatus ?? _state.voiceLanguage,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: active ? Colors.white70 : AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          formatDuration(_seconds),
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1.5,
                            color: active ? Colors.white : AppColors.text,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 6),
                        _Wave(active: active, paused: _paused),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: _recording
                                  ? _stop
                                  : () => _start(),
                              icon: Icon(
                                _recording ? Icons.stop_rounded : Icons.mic_rounded,
                                size: 20,
                              ),
                              label: Text(_recording ? '停止并保存' : '开始录音'),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    _recording ? AppColors.danger : AppColors.accent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(150, 46),
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (_recording)
                              OutlinedButton.icon(
                                onPressed: _paused ? _resume : _pause,
                                icon: Icon(
                                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                  size: 19,
                                ),
                                label: Text(_paused ? '继续' : '暂停'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(100, 46),
                                  side: BorderSide(
                                      color: active
                                          ? Colors.white54
                                          : AppColors.border),
                                  foregroundColor:
                                      active ? Colors.white : AppColors.text,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(
                      message: _error!,
                      onRetry: _available ? null : _initialize,
                      onDismiss: () => setState(() => _error = null),
                    ),
                  ],
                  if (!_available && _initialized) ...[
                    const SizedBox(height: 10),
                    InfoBanner(
                      text: '语音服务不可用。可在下方手动输入转写文本，AI 纪要仍然可用。',
                      icon: Icons.mic_off_outlined,
                      color: AppColors.warning,
                    ),
                  ],
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('实时转写',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (_savedId != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('已保存',
                                    style: TextStyle(
                                        fontSize: 9, color: AppColors.accentDark)),
                              ),
                            const SizedBox(width: 6),
                            Text('${_transcript.text.length} 字',
                                style: TextStyle(fontSize: 10, color: secondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _transcript,
                          minLines: 5,
                          maxLines: 10,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: '录音时系统识别结果会出现在这里；也可以手动输入或修正。',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: TextStyle(
                                fontSize: 13,
                                color: secondary.withValues(alpha: .7),
                                height: 1.5),
                          ),
                          style: const TextStyle(fontSize: 14.5, height: 1.65),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: _transcript.text));
                                if (context.mounted) showToast(context, '转写已复制');
                              },
                              icon: const Icon(Icons.copy_rounded, size: 15),
                              label: const Text('复制', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                _transcript.clear();
                                setState(() {
                                  _summary = null;
                                  _bullets = const [];
                                  _savedId = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline, size: 15),
                              label: const Text('清空', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.save_outlined, size: 15),
                              label: const Text('保存会话',
                                  style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                            ),
                          ],
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
                            const Icon(Icons.auto_awesome_rounded,
                                size: 17, color: AppColors.accentDark),
                            const SizedBox(width: 6),
                            const Text('AI 纪要',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (_summaryLoading)
                              const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_summary == null || _summary!.isEmpty)
                          Text(
                            '把转写文本发送到自建后端，生成简洁摘要与要点。不会自动上传，需要你点击生成。',
                            style: TextStyle(fontSize: 12, color: secondary, height: 1.55),
                          )
                        else ...[
                          SelectableText(_summary!,
                              style: const TextStyle(fontSize: 14, height: 1.65)),
                          if (_bullets.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ..._bullets.map((bullet) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 7),
                                        child: Icon(Icons.circle,
                                            size: 4, color: AppColors.accent),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(bullet,
                                            style: const TextStyle(
                                                fontSize: 12.5, height: 1.55)),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _summaryLoading ? null : _summarize,
                                icon: const Icon(Icons.summarize_outlined, size: 18),
                                label: Text(_summary == null ? '生成纪要' : '重新生成'),
                              ),
                            ),
                            if (_summary != null) ...[
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                tooltip: '复制纪要',
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(
                                      text: '$_summary\n${_bullets.map((e) => '· $e').join('\n')}'));
                                  if (context.mounted) showToast(context, '纪要已复制');
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '录音转写使用系统语音识别；音频本身不写入文件，只保存你确认的转写文本。AI 纪要发送文本到 ${state.apiBaseUrl}。',
                    style: TextStyle(fontSize: 10.5, color: secondary, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/recorder/session'),
                    icon: const Icon(Icons.library_music_outlined, size: 18),
                    label: Text('查看录音会话（${state.sessions.length}）'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wave extends StatelessWidget {
  final bool active;
  final bool paused;
  const _Wave({required this.active, required this.paused});

  @override
  Widget build(BuildContext context) {
    final heights = [8.0, 16.0, 24.0, 12.0, 20.0, 9.0, 15.0, 22.0, 11.0];
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: heights.map((height) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3,
            height: active ? height : (paused ? 4 : 5),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: .8)
                  : AppColors.accent.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class RecorderSessionsPage extends StatefulWidget {
  const RecorderSessionsPage({super.key});

  @override
  State<RecorderSessionsPage> createState() => _RecorderSessionsPageState();
}

class _RecorderSessionsPageState extends State<RecorderSessionsPage> {
  bool _summarizing = false;
  String? _error;

  Future<void> _showDetail(RecorderSession session) async {
    final state = AppScope.read(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          final secondary =
              dark ? AppColors.darkSecondary : AppColors.textSecondary;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                      '${formatDateTime(session.createdAt)} · ${formatDuration(session.durationSeconds)}',
                      style: TextStyle(fontSize: 11, color: secondary)),
                  const SizedBox(height: 14),
                  Text('转写',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: secondary)),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 190),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        session.transcript.isEmpty ? '（空）' : session.transcript,
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('AI 纪要',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: secondary)),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        session.summary.isEmpty ? '尚未生成纪要' : session.summary,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: session.summary.isEmpty ? secondary : null),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: session.transcript));
                            if (context.mounted) showToast(context, '转写已复制');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 17),
                          label: const Text('复制转写'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _summarizing
                              ? null
                              : () async {
                                  setSheet(() => _summarizing = true);
                                  try {
                                    final data = await ApiClient.fromState(state)
                                        .summarize(session.transcript,
                                            title: session.title);
                                    final summary =
                                        (data['text'] ?? data['summary'] ?? '').toString();
                                    await state.updateSession(
                                        session.copyWith(summary: summary));
                                    setSheet(() {
                                      _summarizing = false;
                                      _error = null;
                                    });
                                    if (context.mounted) {
                                      showToast(context, '纪要已生成并保存');
                                      Navigator.pop(context);
                                    }
                                  } on ApiException catch (e) {
                                    setSheet(() {
                                      _summarizing = false;
                                      _error = e.message;
                                    });
                                  }
                                },
                          icon: _summarizing
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_awesome_rounded, size: 17),
                          label: Text(_summarizing ? '生成中' : '生成纪要'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () async {
                          final ok = await confirmAction(context,
                              title: '删除会话',
                              message: '删除「${session.title}」？',
                              confirm: '删除',
                              danger: true);
                          if (!ok) return;
                          await state.removeSession(session.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline, size: 19),
                        color: AppColors.danger,
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.danger, height: 1.4)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final sessions = state.sessions;
    return Scaffold(
      appBar: AppBar(title: const Text('录音会话')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: sessions.isEmpty
              ? EmptyState(
                  icon: Icons.library_music_outlined,
                  title: '还没有录音会话',
                  subtitle: '在 AI 录音笔中开始录音，停止后会自动保存到本机。',
                  action: FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/recorder'),
                    icon: const Icon(Icons.mic_none_rounded, size: 18),
                    label: const Text('去录音'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return AppCard(
                      onTap: () => _showDetail(session),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.graphic_eq_rounded,
                                size: 21, color: AppColors.accentDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(session.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Text(
                                  '${formatDateTime(session.createdAt)} · ${formatDuration(session.durationSeconds)} · ${session.transcript.length} 字',
                                  style: TextStyle(fontSize: 10.5, color: secondary),
                                ),
                                if (session.summary.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    session.summary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11, color: secondary, height: 1.4),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
