import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ServiceSettingsPage extends StatefulWidget {
  const ServiceSettingsPage({super.key});

  @override
  State<ServiceSettingsPage> createState() => _ServiceSettingsPageState();
}

class _ServiceSettingsPageState extends State<ServiceSettingsPage> {
  late final TextEditingController _base;
  late final TextEditingController _token;
  bool _busy = false;
  String? _error;
  String? _health;
  String? _chatReply;

  @override
  void initState() {
    super.initState();
    _base = TextEditingController();
    _token = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.read(context);
      _base.text = state.apiBaseUrl;
      _token.text = state.appToken;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _base.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save(AppState state) async {
    await state.setApiBaseUrl(_base.text);
    await state.setAppToken(_token.text);
    _base.text = state.apiBaseUrl;
    if (mounted) showToast(context, '服务地址已保存');
  }

  Future<void> _check(AppState state, {bool sendMessage = false}) async {
    await _save(state);
    setState(() {
      _busy = true;
      _error = null;
      _health = null;
      _chatReply = null;
    });
    try {
      final api = ApiClient.fromState(state);
      final health = await api.health();
      final key = health['key'];
      final keyText = key is Map
          ? (key['configured'] == true
              ? '已配置（${key['prefix'] ?? ''}… / ${key['length'] ?? '?'} 字符）'
              : '未配置')
          : '未知';
      setState(() {
        _health = '模型 ${health['model']} · ASR ${health['asr'] ?? 'device'}\n'
            '后端：${health['base_url'] ?? state.apiBaseUrl}\n模型密钥：$keyText';
      });
      if (sendMessage) {
        final reply = await api.chat([
          {'role': 'user', 'content': '请只回复 OK 两个字母。'},
        ], maxTokens: 20);
        setState(() => _chatReply = reply);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '请求失败：$e');
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
      title: '服务设置',
      subtitle: 'AI、翻译与同步共用的后端地址。客户端不保存模型密钥。',
      children: [
        if (state.standalone)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: InfoBanner(
              text: '单机模式已开启：保存地址不会联网，检查与 AI 测试会被拒绝。',
              icon: Icons.flight_takeoff_rounded,
              color: AppColors.warning,
            ),
          ),
        SettingCard(
          title: 'API 基础地址',
          description: 'Android 模拟器默认 http://10.0.2.2:8787；iOS 模拟器默认 http://127.0.0.1:8787。真机请填 Mac 的局域网地址。',
          child: Column(
            children: [
              TextField(
                controller: _base,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'http://10.0.2.2:8787',
                  prefixIcon: Icon(Icons.dns_outlined, size: 19),
                ),
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _base.text = AppState.defaultApiBase;
                      },
                      child: const Text('使用平台默认'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _save(state),
                      child: const Text('保存地址'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SettingCard(
          title: '应用令牌（可选）',
          description: '仅当后端设置了 WETYPE_APP_TOKEN 时需要。它不是模型密钥，不应填入 sk- 开头的字符串。',
          child: TextField(
            controller: _token,
            obscureText: true,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: '留空表示后端未启用应用令牌',
              prefixIcon: Icon(Icons.vpn_key_outlined, size: 19),
            ),
            style: const TextStyle(fontSize: 13.5),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _check(state),
                icon: _busy
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.network_check_rounded, size: 18),
                label: const Text('检查连接'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _check(state, sendMessage: true),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('测试 AI 回复'),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(message: _error!, onRetry: () => _check(state)),
        ],
        if (_health != null) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 18, color: AppColors.accentDark),
                    SizedBox(width: 6),
                    Text('连接正常',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentDark)),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(_health!,
                    style: TextStyle(fontSize: 11.5, color: secondary, height: 1.55)),
                if (_chatReply != null) ...[
                  const Divider(height: 22),
                  Text('AI 回复：$_chatReply',
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        const InfoBanner(
          text: '若后端不可达，AI 页面会显示具体错误与重试按钮，不会伪造回答。公开构建中不包含任何模型密钥。',
          icon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: 12),
        Text(
          '当前：${state.apiBaseUrl}${state.appToken.isEmpty ? ' · 未设置应用令牌' : ' · 已设置应用令牌'}\n'
          '平台默认：${AppState.defaultApiBase}',
          style: TextStyle(fontSize: 10.5, color: secondary, height: 1.6),
        ),
      ],
    );
  }
}
