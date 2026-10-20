import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class VoiceInputSheet extends StatefulWidget {
  final bool autoStart;
  const VoiceInputSheet({super.key, this.autoStart = true});

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet> {
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _controller = TextEditingController();
  bool _available = false;
  bool _listening = false;
  bool _keepListening = false;
  String? _error;
  String _status = '正在初始化语音识别…';
  Timer? _elapsed;
  int _seconds = 0;
  bool _restarting = false;

  AppState get _state => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _error = null;
      _status = '正在请求麦克风与语音识别权限…';
    });
    try {
      final available = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: false,
      );
      if (!mounted) return;
      setState(() {
        _available = available;
        _status = available ? '准备就绪' : '设备语音识别不可用';
        if (!available) {
          _error = '当前设备或模拟器没有可用的语音识别服务。你仍可手动编辑下方文本，或连接真机后重试。';
        }
      });
      if (available && widget.autoStart) {
        await _start();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _available = false;
        _error = '语音识别初始化失败：$e';
        _status = '不可用';
      });
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    final permanent = error.permanent;
    setState(() {
      _error = '语音识别错误：${error.errorMsg}';
      _listening = false;
      if (permanent) _keepListening = false;
    });
  }

  void _onStatus(String status) {
    if (!mounted) return;
    setState(() {
      _status = switch (status) {
        'listening' => '正在聆听…',
        'notListening' => '已暂停',
        'done' => '识别结束',
        _ => status,
      };
      if (status == 'listening') _listening = true;
      if (status == 'notListening' || status == 'done') _listening = false;
    });
    if ((status == 'done' || status == 'notListening') &&
        _keepListening &&
        _available &&
        !_restarting) {
      _restarting = true;
      Future.delayed(const Duration(milliseconds: 350), () async {
        _restarting = false;
        if (mounted && _keepListening && !_speech.isListening) {
          await _start();
        }
      });
    }
  }

  Future<void> _start() async {
    if (!_available) {
      await _initialize();
      if (!_available) return;
    }
    _keepListening = true;
    setState(() {
      _error = null;
      _seconds = 0;
    });
    _elapsed?.cancel();
    _elapsed = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
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
      if (!mounted) return;
      setState(() => _listening = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '无法开始语音识别：$e';
        _listening = false;
        _keepListening = false;
      });
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _controller.text = result.recognizedWords;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
      if (result.finalResult) _status = '已得到最终结果，可继续说话';
    });
  }

  Future<void> _stop() async {
    _keepListening = false;
    _elapsed?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _listening = false;
        _status = '已停止';
      });
    }
  }

  String _applyPunctuation(String text) {
    final mode = _state.voicePunctuation;
    if (text.isEmpty) return text;
    if (mode == 'space') return '$text ';
    if (mode != 'smart') return text;
    const endings = ['。', '！', '？', '.', '!', '?', '，', ',', '；', ';', '：', ':', '…'];
    if (endings.any(text.endsWith)) return text;
    final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    return text + (hasChinese ? '。' : '.');
  }

  Future<void> _finish() async {
    await _stop();
    if (!mounted) return;
    final text = _applyPunctuation(_controller.text.trim());
    Navigator.pop(context, text);
  }

  @override
  void dispose() {
    _elapsed?.cancel();
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('语音转文字', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _listening
                      ? AppColors.accent.withValues(alpha: .15)
                      : secondary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _listening ? '聆听中 ${_seconds}s' : _status,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: _listening ? AppColors.accentDark : secondary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _state.voiceLanguage,
                style: TextStyle(fontSize: 11, color: secondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            ErrorBanner(message: _error!, onRetry: _initialize),
            const SizedBox(height: 12),
          ],
          Container(
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 220),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dark ? AppColors.darkBorder : AppColors.border),
            ),
            child: SingleChildScrollView(
              child: TextField(
                controller: _controller,
                maxLines: null,
                minLines: 4,
                decoration: InputDecoration(
                  hintText: _listening ? '请开始说话…' : '识别结果会出现在这里，也可以手动编辑',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(fontSize: 14, color: secondary.withValues(alpha: .7)),
                ),
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (_available)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _listening ? _stop : _start,
                    icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
                    label: Text(_listening ? '停止聆听' : '开始说话'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _listening ? AppColors.danger : AppColors.accent,
                    ),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _initialize,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试语音权限'),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _finish,
                  child: const Text('完成并插入'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '语音识别由系统/设备提供，离线能力取决于设备。标点策略：${_state.voicePunctuation == 'smart' ? '智能标点' : _state.voicePunctuation == 'space' ? '追加空格' : '不处理'}。',
            style: TextStyle(fontSize: 10.5, color: secondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
