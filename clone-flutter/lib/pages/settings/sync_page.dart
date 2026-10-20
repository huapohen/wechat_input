import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  bool _busy = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController();
    _name = TextEditingController(text: '微输入法 Flutter');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.read(context);
      _code.text = state.syncCode.isEmpty ? state.generatePairCode() : state.syncCode;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pair(AppState state) async {
    final code = _code.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length != 6) {
      setState(() => _error = '请输入 6 位数字配对码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final api = ApiClient.fromState(state);
      final result = await api.pair(code, name: _name.text.trim().isEmpty ? '微输入法' : _name.text.trim());
      final token = (result['token'] ?? '').toString();
      final peer = result['peer'];
      final peerName = peer is Map ? (peer['name'] ?? '另一台设备').toString() : '';
      final peerToken = peer is Map ? (peer['token'] ?? '').toString() : '';
      await state.saveSync(code: code, token: token, peer: peerName, peerToken: peerToken);
      setState(() {
        _status = peer == null
            ? '已注册配对码 $code。请让另一台设备使用同一配对码加入，然后点「刷新配对状态」。'
            : '配对成功，已发现「$peerName」';
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '配对失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '同步失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return SettingsScaffold(
      title: '跨设备粘贴同步',
      subtitle: '通过自建后端的中转空间配对设备。配对码只用于建立本地配对，不是账号。',
      children: [
        if (state.standalone)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ErrorBanner(
              message: '单机模式已开启，跨设备同步不可用。',
              onRetry: () => Navigator.pushNamed(context, '/settings/standalone'),
            ),
          ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('配对',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (state.syncConnected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('已配对',
                          style: TextStyle(fontSize: 10, color: AppColors.accentDark)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6 位配对码',
                  hintText: '两台设备输入同一个码',
                  counterText: '',
                ),
                style: const TextStyle(fontSize: 20, letterSpacing: 6),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '设备名称'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _pair(state),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.link_rounded, size: 18),
                      label: Text(state.syncConnected ? '刷新配对状态' : '配对'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '生成新码',
                    onPressed: () {
                      setState(() => _code.text = state.generatePairCode());
                    },
                    icon: const Icon(Icons.casino_outlined),
                  ),
                  IconButton(
                    tooltip: '复制配对码',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _code.text));
                      if (context.mounted) showToast(context, '配对码已复制');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 20),
                  ),
                ],
              ),
              if (state.syncConnected) ...[
                const SizedBox(height: 10),
                Divider(color: dark ? AppColors.darkBorder : AppColors.border),
                const SizedBox(height: 6),
                Text('本机 token：${_mask(state.syncToken)}',
                    style: TextStyle(fontSize: 10.5, color: secondary)),
                const SizedBox(height: 2),
                Text(
                  state.syncPeer.isEmpty
                      ? '尚未发现另一台设备。让另一台设备用配对码 ${state.syncCode} 加入后刷新。'
                      : '对端：${state.syncPeer}${state.syncPeerToken.isEmpty ? '（无对端 token）' : ''}',
                  style: TextStyle(fontSize: 11, color: secondary, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(
            message: _error!,
            onRetry: () => _pair(state),
            onDismiss: () => setState(() => _error = null),
          ),
        ],
        if (_status != null) ...[
          const SizedBox(height: 10),
          InfoBanner(text: _status!, icon: Icons.check_circle_outline_rounded),
        ],
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Column(
            children: [
              ToggleRow(
                title: '同步剪贴板',
                subtitle: '允许本机主动拉取/发送剪贴板文本',
                value: state.syncClipboard,
                onChanged: (v) => state.setFlag('sync.clipboard', v),
              ),
              const Divider(),
              ToggleRow(
                title: '同步常用语',
                subtitle: '与配对设备合并常用语',
                value: state.syncPhrases,
                onChanged: (v) => state.setFlag('sync.phrases', v),
              ),
              const Divider(),
              ToggleRow(
                title: '同步设置',
                subtitle: '上传布局、语音、Plus 等偏好（不含密钥）',
                value: state.syncSettings,
                onChanged: (v) => state.setFlag('sync.settings', v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('同步动作', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondary)),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ActionRow(
                icon: Icons.content_paste_go_outlined,
                title: '发送剪贴板到配对空间',
                subtitle: state.syncPeerToken.isEmpty
                    ? '上传到本机同步空间'
                    : '写入「${state.syncPeer}」的同步空间',
                onTap: _busy || !state.syncClipboard
                    ? null
                    : () => _run(() async {
                          final api = ApiClient.fromState(state);
                          final token = state.syncPeerToken.isEmpty
                              ? state.syncToken
                              : state.syncPeerToken;
                          final items = await api.pushClipboard(token, state.clipboard);
                          setState(() => _status = '已发送，远端当前共 ${items.length} 条剪贴板');
                        }),
              ),
              const Divider(),
              ActionRow(
                icon: Icons.content_paste_search_outlined,
                title: '拉取对方剪贴板',
                subtitle: '从对端 token 读取并与本机历史合并',
                onTap: _busy || !state.syncClipboard
                    ? null
                    : () => _run(() async {
                          if (state.syncPeerToken.isEmpty) {
                            throw ApiException('未发现对端 token，请先让另一台设备加入同一配对码。');
                          }
                          final api = ApiClient.fromState(state);
                          final items = await api.pullClipboard(state.syncPeerToken);
                          final merged = <String>[...items, ...state.clipboard];
                          final unique = <String>[];
                          for (final item in merged) {
                            if (!unique.contains(item)) unique.add(item);
                          }
                          await state.setClipboard(unique);
                          setState(() => _status = '拉取 ${items.length} 条，本机现有 ${unique.length} 条');
                        }),
              ),
              const Divider(),
              ActionRow(
                icon: Icons.format_quote_rounded,
                title: '合并常用语',
                subtitle: '把本机常用语写入配对空间并取回合并结果',
                onTap: _busy || !state.syncPhrases
                    ? null
                    : () => _run(() async {
                          final api = ApiClient.fromState(state);
                          final token = state.syncPeerToken.isEmpty
                              ? state.syncToken
                              : state.syncPeerToken;
                          final merged = await api.pushPhrases(token, state.phrases);
                          await state.setPhrases(merged);
                          setState(() => _status = '常用语已合并，共 ${merged.length} 条');
                        }),
              ),
              const Divider(),
              ActionRow(
                icon: Icons.cloud_upload_outlined,
                title: '上传设置',
                subtitle: '把当前偏好写入本机同步空间',
                onTap: _busy || !state.syncSettings
                    ? null
                    : () => _run(() async {
                          final api = ApiClient.fromState(state);
                          await api.pushSettings(state.syncToken, {
                            'theme': state.themeMode,
                            'candidateSize': state.candidateSize,
                            'keyboardScale': state.keyboardScale,
                            'voiceLanguage': state.voiceLanguage,
                            'fuzzyPairs': state.fuzzyPairs.toList(),
                            'toolbar': state.toolbarOrder,
                            'plus': state.plusEnabled,
                          });
                          setState(() => _status = '设置已上传');
                        }),
              ),
              const Divider(),
              ActionRow(
                icon: Icons.cloud_download_outlined,
                title: '下载设置',
                subtitle: '从对端或本机同步空间恢复偏好',
                onTap: _busy || !state.syncSettings
                    ? null
                    : () => _run(() async {
                          final api = ApiClient.fromState(state);
                          final token = state.syncPeerToken.isEmpty
                              ? state.syncToken
                              : state.syncPeerToken;
                          final payload = await api.pullSettings(token);
                          if (payload.isEmpty) {
                            throw ApiException('同步空间中没有设置');
                          }
                          final settings = payload['settings'] is Map
                              ? Map<String, dynamic>.from(payload['settings'] as Map)
                              : payload;
                          var count = 0;
                          final theme = settings['theme'];
                          if (theme is String) {
                            await state.setThemeMode(theme);
                            count++;
                          }
                          final size = settings['candidateSize'];
                          if (size is num) {
                            await state.setCandidateSize(size.toDouble());
                            count++;
                          }
                          final scale = settings['keyboardScale'];
                          if (scale is num) {
                            await state.setKeyboardScale(scale.toDouble());
                            count++;
                          }
                          final lang = settings['voiceLanguage'];
                          if (lang is String) {
                            await state.setVoiceLanguage(lang);
                            count++;
                          }
                          final pairs = settings['fuzzyPairs'];
                          if (pairs is List) {
                            await state.setStrings(
                                'fuzzy.pairs', pairs.map((e) => e.toString()).toList());
                            count++;
                          }
                          final toolbar = settings['toolbar'];
                          if (toolbar is List) {
                            await state.setToolbarOrder(
                                toolbar.map((e) => e.toString()).toList());
                            count++;
                          }
                          final plus = settings['plus'];
                          if (plus is bool) {
                            await state.setPlusEnabled(plus);
                            count++;
                          }
                          setState(() => _status = '已恢复 $count 组设置');
                        }),
              ),
              if (state.syncConnected) ...[
                const Divider(),
                ActionRow(
                  icon: Icons.link_off_rounded,
                  title: '断开配对',
                  subtitle: '仅删除本机保存的 token，不删除后端数据',
                  danger: true,
                  onTap: () async {
                    final ok = await confirmAction(context,
                        title: '断开配对',
                        message: '断开后需要重新输入配对码才能同步。',
                        confirm: '断开',
                        danger: true);
                    if (ok) {
                      await state.clearSync();
                      if (context.mounted) {
                        setState(() {
                          _status = null;
                          _error = null;
                        });
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const InfoBanner(
          text: '配对码不是账号。后端只在局域网/自建服务中保存设备 token 与同步内容；单机模式下所有同步请求会被拒绝。',
          icon: Icons.security_rounded,
        ),
      ],
    );
  }
}

String _mask(String token) {
  if (token.length <= 8) return token;
  return '${token.substring(0, 4)}…${token.substring(token.length - 4)}';
}
