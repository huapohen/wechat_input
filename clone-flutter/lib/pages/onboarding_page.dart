import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _agree = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _agree = AppScope.read(context).acceptedPrivacy;
    }
  }

  Future<void> _start() async {
    final state = AppScope.read(context);
    await state.acceptPrivacy();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF25C894), Color(0xFF0E8A68)],
                        ),
                      ),
                      child: const Icon(Icons.keyboard_alt_rounded,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('微输入法',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w700)),
                          Text('启用与隐私',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/settings/privacy'),
                      child: const Text('权限清单'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('先了解，再开始',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: dark ? AppColors.darkText : AppColors.text)),
                const SizedBox(height: 8),
                Text(
                  '这是一个独立的学习复刻版本。没有账号体系，不读取聊天记录，不把输入内容上传到服务器。',
                  style: TextStyle(fontSize: 14, color: secondary, height: 1.65),
                ),
                const SizedBox(height: 24),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _PrivacyLine(
                        icon: Icons.phonelink_lock_outlined,
                        title: '输入内容留在本机',
                        subtitle: '拼音、五笔、笔画与候选学习都在设备上完成；个人词典存于本机。',
                      ),
                      const SizedBox(height: 16),
                      _PrivacyLine(
                        icon: Icons.auto_awesome_outlined,
                        title: '只有你主动使用的 AI 功能才联网',
                        subtitle: '问 AI、文字整理、翻译、录音纪要会发送你确认过的文本到自建后端；不发送按键记录。',
                      ),
                      const SizedBox(height: 16),
                      _PrivacyLine(
                        icon: Icons.key_outlined,
                        title: '客户端不含模型密钥',
                        subtitle: '模型密钥只存在于后端环境变量；应用只保存可配置的服务地址。',
                      ),
                      const SizedBox(height: 16),
                      _PrivacyLine(
                        icon: Icons.mic_none_rounded,
                        title: '语音需要系统授权',
                        subtitle: '语音转文字使用系统识别服务；拒绝授权时仍可使用键盘、候选与文字输入。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('应用内键盘',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        '本版本提供应用内键盘体验：在「键盘体验」页点击输入框，即可用九宫格、全键盘、手写、五笔、双拼等模式上屏。它不会替换系统输入法。',
                        style: TextStyle(fontSize: 12.5, color: secondary, height: 1.55),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/keyboard'),
                              icon: const Icon(Icons.keyboard_outlined, size: 18),
                              label: const Text('先试试键盘'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/settings/standalone'),
                              icon: const Icon(Icons.flight_takeoff_outlined, size: 18),
                              label: const Text('单机模式'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () => setState(() => _agree = !_agree),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agree,
                          onChanged: (v) => setState(() => _agree = v ?? false),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: Text(
                              '我已阅读并同意隐私说明。微输入法为独立学习复刻，与腾讯无任何关联。',
                              style: TextStyle(fontSize: 12.5, color: secondary, height: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _agree ? _start : null,
                  child: Text(state.acceptedPrivacy ? '进入首页' : '开始使用'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/more/about'),
                    child: const Text('了解识别范围与限制'),
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

class _PrivacyLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PrivacyLine({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSecondary
        : AppColors.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: AppColors.accentDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: secondary, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
