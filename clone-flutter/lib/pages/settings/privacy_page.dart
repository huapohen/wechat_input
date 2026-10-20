import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  String _speechStatus = '未检查';
  String _micStatus = '未检查';
  bool _checking = false;

  Future<void> _checkPermissions() async {
    setState(() {
      _checking = true;
      _speechStatus = '检查中…';
      _micStatus = '检查中…';
    });
    final speech = SpeechToText();
    try {
      final available = await speech.initialize(
        onError: (error) {},
        onStatus: (status) {},
        debugLogging: false,
      );
      setState(() {
        _speechStatus = available ? '可用' : '不可用';
        _micStatus = available ? '已授权或可用' : '未授权 / 不可用';
      });
    } catch (e) {
      setState(() {
        _speechStatus = '不可用';
        _micStatus = '未授权 / 不可用';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openSystemSettings() async {
    final uri = Uri.parse('app-settings:');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        showToast(context, '无法自动打开系统设置，请手动前往「设置 → 应用 → 微输入法」。');
      }
    } catch (_) {
      if (mounted) {
        showToast(context, '无法自动打开系统设置，请手动前往系统设置。');
      }
    }
  }

  Future<void> _clearAll(AppState state) async {
    final ok = await confirmAction(
      context,
      title: '清除所有本地数据',
      message: '将删除设置、词库学习、常用语、剪贴板历史、聊天记录、录音会话与反馈。此操作不可撤销。',
      confirm: '全部清除',
      danger: true,
    );
    if (!ok) return;
    await state.resetEverything();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return SettingsScaffold(
      title: '隐私与权限',
      subtitle: '这是独立学习复刻版本，与腾讯无关联。以下为本机数据与授权状态。',
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 20, color: AppColors.accentDark),
                  const SizedBox(width: 8),
                  const Text('权限状态',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (_checking)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 10),
              _PermissionRow(
                icon: Icons.mic_none_rounded,
                title: '麦克风',
                status: _micStatus,
                onCheck: _checkPermissions,
              ),
              _PermissionRow(
                icon: Icons.record_voice_over_outlined,
                title: '语音识别',
                status: _speechStatus,
                onCheck: _checkPermissions,
              ),
              _PermissionRow(
                icon: Icons.content_paste_off_outlined,
                title: '剪贴板',
                status: '仅在点击「读取系统剪贴板」时读取',
                onCheck: null,
              ),
              _PermissionRow(
                icon: Icons.folder_outlined,
                title: '文件访问',
                status: '通过系统文件选择器选择，不遍历目录',
                onCheck: null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _checking ? null : _checkPermissions,
                      icon: const Icon(Icons.verified_user_outlined, size: 18),
                      label: const Text('检查语音权限'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openSystemSettings,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('系统设置'),
                    ),
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
              const Text('数据处理说明',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                '• 键盘输入、候选排序、个人词典、常用语与剪贴板历史保存在本机 SharedPreferences。\n'
                '• 按键记录不上传；应用没有账号体系。\n'
                '• AI 请求只发送你在输入框中确认过的文本，不发送按键历史。\n'
                '• 文件上传只发送你选择的文件，并显示真实进度。\n'
                '• 客户端不包含模型密钥；服务地址可在「服务设置」中修改。',
                style: TextStyle(fontSize: 12, color: secondary, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader('本机数据'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ValueRow(
                title: '常用语',
                value: '${state.phrases.length} 条',
                icon: Icons.format_quote_rounded,
                onTap: () => Navigator.pushNamed(context, '/phrases'),
              ),
              const Divider(),
              ValueRow(
                title: '个人词典学习词',
                value: '${state.userFreq.length} 个',
                icon: Icons.spellcheck_rounded,
                onTap: () => Navigator.pushNamed(context, '/settings/auxiliary'),
              ),
              const Divider(),
              ValueRow(
                title: '剪贴板历史',
                value: '${state.clipboard.length} 条',
                icon: Icons.content_paste_rounded,
                onTap: () => Navigator.pushNamed(context, '/settings/clipboard'),
              ),
              const Divider(),
              ValueRow(
                title: 'AI 对话记录',
                value: '${state.chat.length} 条',
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => Navigator.pushNamed(context, '/ai'),
              ),
              const Divider(),
              ValueRow(
                title: '录音会话',
                value: '${state.sessions.length} 条',
                icon: Icons.graphic_eq_rounded,
                onTap: () => Navigator.pushNamed(context, '/recorder/session'),
              ),
              const Divider(),
              ValueRow(
                title: '本地存储占用',
                value: '${(state.storageBytes / 1024).toStringAsFixed(1)} KB',
                icon: Icons.storage_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ActionRow(
                icon: Icons.delete_outline_rounded,
                title: '清除个人词典',
                subtitle: '学习词频、固定词与删除记录',
                onTap: () async {
                  final ok = await confirmAction(context,
                      title: '清除个人词典',
                      message: '将删除本机学习的候选偏好。',
                      confirm: '清除',
                      danger: true);
                  if (ok) {
                    await state.clearPersonalDictionary();
                    if (context.mounted) showToast(context, '已清除个人词典');
                  }
                },
              ),
              const Divider(),
              ActionRow(
                icon: Icons.content_paste_off_rounded,
                title: '清除剪贴板历史',
                subtitle: '不影响系统剪贴板当前内容',
                onTap: () async {
                  final ok = await confirmAction(context,
                      title: '清除剪贴板历史',
                      message: '将删除本机保存的剪贴板记录。',
                      confirm: '清除',
                      danger: true);
                  if (ok) {
                    await state.setClipboard([]);
                    if (context.mounted) showToast(context, '已清除');
                  }
                },
              ),
              const Divider(),
              ActionRow(
                icon: Icons.delete_forever_outlined,
                title: '清除所有本地数据',
                subtitle: '恢复到首次启动状态',
                danger: true,
                onTap: () => _clearAll(state),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/onboarding'),
                icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                label: const Text('隐私说明'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/more/about'),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: const Text('关于与限制'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '本应用不声称与腾讯存在隶属、授权或合作关系。界面与交互为学习性重建设计。',
          style: TextStyle(fontSize: 10.5, color: secondary, height: 1.5),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final VoidCallback? onCheck;
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.status,
    this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSecondary
        : AppColors.textSecondary;
    final ok = status == '可用' || status == '已授权或可用';
    final bad = status == '不可用' || status == '未授权 / 不可用';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 19, color: secondary),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5))),
          Text(
            status,
            style: TextStyle(
              fontSize: 10.5,
              color: ok ? AppColors.accentDark : bad ? AppColors.danger : secondary,
            ),
          ),
          if (onCheck != null)
            IconButton(
              onPressed: onCheck,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              visualDensity: VisualDensity.compact,
              color: secondary,
            ),
        ],
      ),
    );
  }
}
