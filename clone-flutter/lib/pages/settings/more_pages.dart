import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class DesktopPage extends StatelessWidget {
  const DesktopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return SettingsScaffold(
      title: '电脑版',
      subtitle: '让手机与电脑在同一局域网内传文件、同步剪贴板。当前交付不包含桌面安装包。',
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.desktop_windows_rounded,
                        size: 27, color: AppColors.accentDark),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('微输入法 · 跨设备',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('同一 Wi-Fi · 自建后端 · 无需账号',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Step(number: '1', text: '确保手机与电脑连接同一个 Wi-Fi。'),
              _Step(number: '2', text: '在电脑浏览器访问后端服务地址；在手机上打开「隔空传送」上传文件。'),
              _Step(number: '3', text: '在「跨设备粘贴同步」输入同一个 6 位配对码，即可拉取剪贴板与常用语。'),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('服务地址', style: TextStyle(fontSize: 10.5, color: secondary)),
                    const SizedBox(height: 3),
                    SelectableText(state.apiBaseUrl,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text('当前 API 地址；电脑端需使用 Mac 的局域网 IP，而不是 10.0.2.2。',
                        style: TextStyle(fontSize: 10, color: secondary, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: state.apiBaseUrl));
                        if (context.mounted) showToast(context, '服务地址已复制');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('复制地址'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/settings/service'),
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: const Text('修改地址'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FeatureTile(
                icon: Icons.send_rounded,
                title: '隔空传送',
                subtitle: '上传、列出、下载文件',
                onTap: () => Navigator.pushNamed(context, '/transfer'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FeatureTile(
                icon: Icons.devices_other_rounded,
                title: '粘贴同步',
                subtitle: '剪贴板与常用语',
                onTap: () => Navigator.pushNamed(context, '/settings/sync'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InfoBanner(
          text: '桌面版应用尚未在本交付中实现；此页提供可验证的跨设备中转路径，不伪装成已安装的桌面客户端。',
          icon: Icons.info_outline_rounded,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;
  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSecondary
        : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .13),
              shape: BoxShape.circle,
            ),
            child: Text(number,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDark)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text,
                  style: TextStyle(fontSize: 12.5, color: secondary, height: 1.55)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSecondary
        : AppColors.textSecondary;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: AppColors.accentDark),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10.5, color: secondary)),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return SettingsScaffold(
      title: '关于',
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF25C894), Color(0xFF0E8A68)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.keyboard_alt_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 12),
              const Text('微输入法',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('版本 1.0.0 (1) · Flutter 3.47.2',
                  style: TextStyle(fontSize: 11.5, color: secondary)),
              const SizedBox(height: 12),
              Text(
                '独立学习复刻。与腾讯或微信输入法不存在隶属、授权或合作关系。未使用腾讯的二进制、字体或图片资源。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: secondary, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader('能力与边界'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Column(
            children: [
              const ValueRow(
                  title: '运行平台', value: 'Android / iOS', icon: Icons.phone_android_rounded),
              const Divider(),
              ValueRow(
                title: '键盘形态',
                value: '应用内键盘（不替换系统输入法）',
                icon: Icons.keyboard_outlined,
              ),
              const Divider(),
              const ValueRow(
                  title: '识别引擎', value: '本地词库 + 规则匹配', icon: Icons.memory_rounded),
              const Divider(),
              const ValueRow(
                  title: '手写范围',
                  value: '常用字 · 方向模板',
                  icon: Icons.gesture_rounded),
              const Divider(),
              ValueRow(
                title: 'AI 服务',
                value: '自建后端 · 可配置',
                icon: Icons.cloud_outlined,
              ),
              const Divider(),
              const ValueRow(
                  title: '模型密钥',
                  value: '仅后端环境变量',
                  icon: Icons.key_off_outlined),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('已知限制',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                '• 应用内键盘不会出现在其他应用的输入框中；原生 Android/iOS 版本另行交付。\n'
                '• 手写识别使用五种基本笔画的方向模板，覆盖常用字，准确率有限。\n'
                '• 拼音候选来自共享公开词表，未包含腾讯私有语言模型排序。\n'
                '• 语音识别依赖系统服务；模拟器可能不可用。\n'
                '• AI 质量取决于后端所连模型；后端离线时会显示错误。\n'
                '• 电脑版页面只提供跨设备中转，不包含桌面安装包。',
                style: TextStyle(fontSize: 12, color: secondary, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: '微输入法',
                  applicationVersion: '1.0.0 (1)',
                  applicationLegalese: 'Independent study clone. Not affiliated with Tencent.',
                ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('开源许可'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings/service'),
                icon: const Icon(Icons.dns_outlined, size: 18),
                label: const Text('服务设置'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            '系统：${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n'
            '构建：Flutter release / Material 3\n'
            '设计参考：shared/spec/design_tokens.json',
            style: TextStyle(fontSize: 10.5, color: secondary, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final TextEditingController _text = TextEditingController();
  String _category = '键盘';
  bool _submitting = false;
  String? _status;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState state) async {
    if (_text.text.trim().isEmpty) {
      setState(() => _status = '请先填写反馈内容');
      return;
    }
    setState(() {
      _submitting = true;
      _status = null;
    });
    try {
      await state.addFeedback(FeedbackEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        category: _category,
        text: _text.text.trim(),
        createdAt: DateTime.now(),
      ));
      _text.clear();
      setState(() => _status = '反馈已保存到本机。本版本未提供在线工单接口，不会伪装成已提交。');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _copyDiagnostics(AppState state) async {
    final info = '微输入法 1.0.0 (1)\n'
        'platform=${Platform.operatingSystem}\n'
        'api=${state.apiBaseUrl}\n'
        'standalone=${state.standalone}\n'
        'mode=${state.lastMode}\n'
        'fuzzy=${state.fuzzyPairs.length}\n'
        'phrases=${state.phrases.length}\n'
        'sessions=${state.sessions.length}\n'
        'storage=${state.storageBytes}B';
    await Clipboard.setData(ClipboardData(text: info));
    if (mounted) showToast(context, '诊断信息已复制');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    const faq = [
      ('为什么键盘没有出现在其他应用？', '这是一个应用内键盘复刻，用来验证候选、模式与工具栏。它不会替换系统输入法；需要系统级输入法请使用原生 Android/iOS 版本。'),
      ('候选为空怎么办？', '确认输入编码对应词库；九宫格试 64426（nihao），全键盘试 nihao 或 nh。若显示词库加载失败，点击候选栏重试。'),
      ('AI 页面提示连接失败？', '确认后端已启动，并在「服务设置」检查地址。Android 模拟器使用 10.0.2.2，iOS 模拟器使用 127.0.0.1。单机模式下所有网络请求会被拒绝。'),
      ('语音识别不可用？', '模拟器可能没有语音服务。请在真机授权麦克风与语音识别，或在语音面板底部手动编辑识别文本。'),
      ('手写为什么识别不准？', '手写是轻量方向模板识别，只覆盖常用字，不是腾讯的自然连笔模型。笔画键盘与拼音候选更可靠。'),
      ('文件上传/下载失败？', '检查后端 /health 是否可用、文件大小限制（默认 50 MB）与网络。页面会显示具体错误和重试按钮。'),
    ];
    return SettingsScaffold(
      title: '帮助与反馈',
      subtitle: '先看常见问题；反馈保存在本机，可复制诊断信息。',
      actions: [
        IconButton(
          tooltip: '复制诊断信息',
          onPressed: () => _copyDiagnostics(state),
          icon: const Icon(Icons.bug_report_outlined, size: 21),
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              for (final item in faq)
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  title: Text(item.$1,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(item.$2,
                          style: TextStyle(fontSize: 12, color: secondary, height: 1.6)),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SettingCard(
          title: '反馈',
          description: '选择分类并描述问题。保存后可随时删除。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['键盘', 'AI', '语音', '传文件', '同步', '其他']
                    .map((item) => ChoiceChip(
                          label: Text(item),
                          selected: _category == item,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _category = item),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: '描述你遇到的情况、设备与复现步骤…',
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : () => _submit(state),
                  icon: _submitting
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('保存反馈到本机'),
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Text(_status!,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: _status!.startsWith('请') ? AppColors.danger : AppColors.accentDark,
                        height: 1.45)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('本机反馈记录',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dark ? AppColors.darkText : AppColors.text)),
            const Spacer(),
            Text('${state.feedback.length} 条',
                style: TextStyle(fontSize: 11, color: secondary)),
          ],
        ),
        const SizedBox(height: 8),
        if (state.feedback.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: '暂无反馈',
              subtitle: '保存的反馈只在本机，不会自动上传。',
            ),
          )
        else
          ...state.feedback.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentSoft,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(item.category,
                                      style: const TextStyle(
                                          fontSize: 9, color: AppColors.accentDark)),
                                ),
                                const SizedBox(width: 8),
                                Text(formatDateTime(item.createdAt),
                                    style: TextStyle(fontSize: 9.5, color: secondary)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(item.text,
                                style: const TextStyle(fontSize: 12, height: 1.45)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => state.removeFeedback(item.id),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        color: secondary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 8),
        InfoBanner(
          text: '本版本没有在线工单后端。反馈只会保存在本机；复制诊断信息后可粘贴到你的问题跟踪系统。',
          icon: Icons.privacy_tip_outlined,
        ),
      ],
    );
  }
}
