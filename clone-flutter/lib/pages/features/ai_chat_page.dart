import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AiChatPage extends StatefulWidget {
  final String draft;
  const AiChatPage({super.key, this.draft = ''});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<String>? _subscription;
  ApiClient? _api;
  bool _streaming = false;
  bool _stopping = false;
  String _liveText = '';
  String? _error;
  String? _health;
  bool _checking = false;

  AppState get _state => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    _input.text = widget.draft;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkHealth());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _api?.stopStream();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    final state = _state;
    if (state.standalone) {
      setState(() => _health = '单机模式');
      return;
    }
    setState(() => _checking = true);
    try {
      final data = await ApiClient.fromState(state).health();
      if (mounted) {
        setState(() => _health = '在线 · ${data['model']}');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _health = '离线 · ${e.message.split('\n').first}');
    } catch (_) {
      if (mounted) setState(() => _health = '离线');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send({bool append = true, String? overrideText}) async {
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty) return;
    final state = _state;
    if (state.standalone) {
      setState(() => _error = '单机模式已开启。请先在「单机模式」中关闭联网能力，再使用问 AI。');
      return;
    }
    if (_streaming) return;
    setState(() {
      _error = null;
      _liveText = '';
      _streaming = true;
      _stopping = false;
    });
    if (append) {
      await state.addChat(ChatEntry(
        role: 'user',
        content: text,
        createdAt: DateTime.now(),
      ));
      _input.clear();
    }
    _scrollToBottom();
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': '你是微输入法内置的 AI 助手。回答简洁、直接、不虚构；中文提问用中文回答，代码与术语保留原文。',
      },
      for (final entry in state.chat)
        if (!entry.error) {'role': entry.role, 'content': entry.content},
    ];
    final api = ApiClient.fromState(state);
    _api = api;
    final buffer = StringBuffer();
    try {
      final stream = api.chatStream(messages);
      _subscription = stream.listen(
        (chunk) {
          buffer.write(chunk);
          if (!mounted) return;
          setState(() => _liveText = buffer.toString());
          _scrollToBottom();
        },
        onError: (Object e) async {
          if (_stopping) return;
          final message = e is ApiException ? e.message : '请求失败：$e';
          setState(() {
            _streaming = false;
            _error = message;
          });
          _subscription = null;
          if (buffer.isEmpty) {
            await state.addChat(ChatEntry(
              role: 'assistant',
              content: message,
              error: true,
              createdAt: DateTime.now(),
            ));
          }
          _scrollToBottom();
        },
        onDone: () async {
          if (!mounted || _stopping) return;
          final content = buffer.toString().trim();
          if (content.isNotEmpty) {
            await state.addChat(ChatEntry(
              role: 'assistant',
              content: content,
              createdAt: DateTime.now(),
            ));
          }
          setState(() {
            _streaming = false;
            _liveText = '';
          });
          _subscription = null;
          _scrollToBottom();
        },
        cancelOnError: false,
      );
    } on ApiException catch (e) {
      setState(() {
        _streaming = false;
        _error = e.message;
      });
      await state.addChat(ChatEntry(
        role: 'assistant',
        content: e.message,
        error: true,
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      setState(() {
        _streaming = false;
        _error = '请求失败：$e';
      });
    }
  }

  Future<void> _stop() async {
    _stopping = true;
    _api?.stopStream();
    await _subscription?.cancel();
    _subscription = null;
    if (!mounted) return;
    final partial = _liveText.trim();
    if (partial.isNotEmpty) {
      await _state.addChat(ChatEntry(
        role: 'assistant',
        content: '$partial\n\n（已停止生成）',
        createdAt: DateTime.now(),
      ));
    }
    setState(() {
      _streaming = false;
      _liveText = '';
      _stopping = false;
    });
  }

  Future<void> _retryLast() async {
    if (_streaming) return;
    final state = _state;
    final messages = state.chat;
    int lastUser = -1;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'user') {
        lastUser = i;
        break;
      }
    }
    if (lastUser < 0) {
      setState(() => _error = '没有可重试的问题');
      return;
    }
    final lastText = messages[lastUser].content;
    // Remove trailing error/empty assistant messages so the retry starts clean.
    while (state.chat.isNotEmpty &&
        state.chat.last.role == 'assistant' &&
        (state.chat.last.error || state.chat.last.content.trim().isEmpty)) {
      final list = state.chat.toList()..removeLast();
      await state.setChat(list);
    }
    setState(() => _error = null);
    await _send(append: false, overrideText: lastText);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final messages = state.chat;
    final online = _health?.startsWith('在线') == true;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 19),
            SizedBox(width: 6),
            Text('问 AI'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: online
                  ? AppColors.accent.withValues(alpha: .12)
                  : secondary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                if (_checking)
                  const SizedBox(
                      width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.4))
                else
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? AppColors.accent : secondary,
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  state.standalone
                      ? '单机'
                      : online
                          ? '在线'
                          : '离线',
                  style: TextStyle(
                      fontSize: 9.5,
                      color: online ? AppColors.accentDark : secondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '服务设置',
            onPressed: () => Navigator.pushNamed(context, '/settings/service'),
            icon: const Icon(Icons.tune_rounded, size: 20),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clear') {
                final ok = await confirmAction(context,
                    title: '清空对话',
                    message: '将删除本机保存的全部 AI 对话记录。',
                    confirm: '清空',
                    danger: true);
                if (ok) {
                  await state.clearChat();
                  if (context.mounted) setState(() => _error = null);
                }
              } else if (value == 'retry') {
                _retryLast();
              } else if (value == 'health') {
                _checkHealth();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'retry', child: Text('重试上一次')),
              PopupMenuItem(value: 'health', child: Text('重新检查连接')),
              PopupMenuItem(value: 'clear', child: Text('清空对话')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                if (state.standalone)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: InfoBanner(
                      text: '单机模式：AI 请求被本机拒绝。关闭后可重试。',
                      icon: Icons.flight_takeoff_rounded,
                      color: AppColors.warning,
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ErrorBanner(
                      message: _error!,
                      onRetry: _retryLast,
                      onDismiss: () => setState(() => _error = null),
                    ),
                  ),
                Expanded(
                  child: messages.isEmpty && _liveText.isEmpty
                      ? _EmptyChat(
                          onPrompt: (prompt) {
                            _input.text = prompt;
                            _send();
                          },
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: messages.length + (_liveText.isNotEmpty ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == messages.length && _liveText.isNotEmpty) {
                              return _Bubble(
                                role: 'assistant',
                                text: _liveText,
                                streaming: true,
                                onCopy: null,
                              );
                            }
                            final entry = messages[index];
                            return _Bubble(
                              role: entry.role,
                              text: entry.content,
                              error: entry.error,
                              onCopy: entry.role == 'assistant'
                                  ? () async {
                                      await Clipboard.setData(
                                          ClipboardData(text: entry.content));
                                      if (context.mounted) showToast(context, '已复制回答');
                                    }
                                  : null,
                            );
                          },
                        ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                      14, 8, 14, MediaQuery.paddingOf(context).bottom + 8),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkSurface : AppColors.surface,
                    border: Border(
                        top: BorderSide(
                            color: dark ? AppColors.darkBorder : AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      if (_streaming)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 8),
                              Text('正在生成…', style: TextStyle(fontSize: 11, color: secondary)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _stop,
                                icon: const Icon(Icons.stop_circle_outlined, size: 17),
                                label: const Text('停止'),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    visualDensity: VisualDensity.compact),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: '问点什么…',
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                suffixIcon: IconButton(
                                  tooltip: '插入键盘体验文本',
                                  onPressed: () {
                                    _input.text = '请帮我整理这段文字：${state.chat.isEmpty ? '今天开会讨论了三个问题，第一是进度，第二是排期，第三是风险。' : ''}';
                                  },
                                  icon: const Icon(Icons.keyboard_alt_outlined, size: 19),
                                ),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _streaming ? _stop : () => _send(),
                            icon: Icon(
                              _streaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                              size: 20,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  _streaming ? AppColors.danger : AppColors.accent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('多轮对话 · 流式输出 · 仅本机保存',
                              style: TextStyle(fontSize: 9.5, color: secondary)),
                          const Spacer(),
                          if (messages.any((e) => e.error))
                            TextButton(
                              onPressed: _retryLast,
                              style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                              child: const Text('重试上一次', style: TextStyle(fontSize: 11)),
                            ),
                        ],
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

class _EmptyChat extends StatelessWidget {
  final ValueChanged<String> onPrompt;
  const _EmptyChat({required this.onPrompt});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    const prompts = [
      '帮我写一条简洁的请假消息',
      '把这段会议记录整理成三条要点',
      '用轻松的语气改写这句话：今天加班到很晚',
      '中英混说时，怎样让表达更清楚？',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 34, color: AppColors.accentDark),
          ),
          const SizedBox(height: 14),
          const Text('问 AI',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '写作、改写、翻译、总结。回答只会保存在本机；服务不可达时会明确报错。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: secondary, height: 1.6),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: prompts
                .map((prompt) => ActionChip(
                      label: Text(prompt),
                      labelStyle: const TextStyle(fontSize: 11.5),
                      onPressed: () => onPrompt(prompt),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
          Text('提示：点击输入框右侧键盘图标可快速填入测试文本。',
              style: TextStyle(fontSize: 10, color: secondary)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String role;
  final String text;
  final bool streaming;
  final bool error;
  final VoidCallback? onCopy;
  const _Bubble({
    required this.role,
    required this.text,
    this.streaming = false,
    this.error = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width > 760
                ? 620
                : MediaQuery.sizeOf(context).width * .82),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
        decoration: BoxDecoration(
          color: error
              ? AppColors.danger.withValues(alpha: .08)
              : isUser
                  ? (dark ? const Color(0xFF1F4A3A) : AppColors.accentSoft)
                  : (dark ? AppColors.darkSurface : AppColors.surface),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 18),
          ),
          border: Border.all(
            color: error
                ? AppColors.danger.withValues(alpha: .3)
                : (dark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person_outline_rounded : Icons.auto_awesome_rounded,
                  size: 13,
                  color: error
                      ? AppColors.danger
                      : isUser
                          ? AppColors.accentDark
                          : (dark ? AppColors.darkSecondary : AppColors.textSecondary),
                ),
                const SizedBox(width: 4),
                Text(
                  isUser ? '我' : error ? '错误' : 'AI',
                  style: TextStyle(
                      fontSize: 9.5,
                      color: error
                          ? AppColors.danger
                          : (dark ? AppColors.darkSecondary : AppColors.textSecondary)),
                ),
                if (streaming) ...[
                  const SizedBox(width: 6),
                  const SizedBox(
                      width: 9, height: 9, child: CircularProgressIndicator(strokeWidth: 1.4)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.6,
                color: error
                    ? AppColors.danger
                    : (dark ? AppColors.darkText : AppColors.text),
              ),
            ),
            if (onCopy != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('复制', style: TextStyle(fontSize: 10.5)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: const Size(0, 28),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
