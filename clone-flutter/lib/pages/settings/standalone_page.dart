import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class StandalonePage extends StatefulWidget {
  const StandalonePage({super.key});

  @override
  State<StandalonePage> createState() => _StandalonePageState();
}

class _StandalonePageState extends State<StandalonePage> {
  bool _checking = false;
  String? _error;
  String? _health;

  Future<void> _toggle(AppState state, bool value) async {
    if (value) {
      final ok = await confirmAction(
        context,
        title: '开启单机模式',
        message: '开启后，问 AI、文字整理、翻译、录音纪要、传文件与同步都会被本机拒绝请求。键盘、候选和常用语仍可使用。',
        confirm: '开启',
      );
      if (!ok) return;
    }
    await state.setStandalone(value);
    if (mounted) showToast(context, value ? '单机模式已开启' : '已恢复联网能力');
  }

  Future<void> _check(AppState state) async {
    setState(() {
      _checking = true;
      _error = null;
      _health = null;
    });
    try {
      final data = await ApiClient.fromState(state).health();
      setState(() =>
          _health = '服务可用 · 模型 ${data['model']} · ASR ${data['asr'] ?? 'device'}');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '检查失败：$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return SettingsScaffold(
      title: '单机模式',
      subtitle: '完全本地的输入体验。开启后，所有需要网络的动作都会明确失败，而不是静默降级。',
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: state.standalone
                          ? AppColors.accentSoft
                          : secondary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.flight_takeoff_rounded,
                        size: 25,
                        color: state.standalone ? AppColors.accentDark : secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('单机模式',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(state.standalone ? '已开启 · 纯本地' : '已关闭 · 可用联网功能',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: state.standalone
                                    ? AppColors.accentDark
                                    : secondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.standalone,
                    onChanged: (v) => _toggle(state, v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  state.standalone
                      ? '当前：键盘候选、手写、常用语、剪贴板历史、录音转写（系统本地能力）可用。AI、翻译、文件上传、同步会被拒绝。'
                      : '当前：除本地键盘外，可主动使用自建后端的 AI、翻译、录音纪要与跨设备同步。',
                  style: TextStyle(fontSize: 12, color: secondary, height: 1.55),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader('联网功能检查'),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dns_outlined, size: 18, color: secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(state.apiBaseUrl,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/settings/service'),
                    child: const Text('修改'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _checking ? null : () => _check(state),
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.network_check_rounded, size: 18),
                  label: const Text('检查后端连接'),
                ),
              ),
              if (_health != null) ...[
                const SizedBox(height: 8),
                InfoBanner(text: _health!, icon: Icons.check_circle_outline_rounded),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                ErrorBanner(message: _error!, onRetry: () => _check(state)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoBanner(
          text: '单机模式是本机策略，不是系统级网络开关。开启后客户端会拒绝发起后端请求，后端仍可能被其他设备访问。',
          icon: Icons.info_outline_rounded,
        ),
      ],
    );
  }
}
