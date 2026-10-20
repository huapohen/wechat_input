import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../keyboard/voice_sheet.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

const Map<String, String> kVoiceLanguageNames = {
  'zh_CN': '中文（普通话）',
  'en_US': 'English (US)',
  'zh_HK': '粤语（香港）',
  'zh_TW': '中文（台湾）',
  'ja_JP': '日本語',
};

class VoiceSettingsPage extends StatelessWidget {
  const VoiceSettingsPage({super.key});

  Future<void> _test(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const VoiceInputSheet(autoStart: true),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      showToast(context, '识别结果：$result');
    }
  }

  Future<void> _pickStandby(BuildContext context, AppState state) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('录音待机时间',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final entry in const [
              MapEntry('5', '5 秒'),
              MapEntry('10', '10 秒'),
              MapEntry('30', '30 秒'),
              MapEntry('never', '不自动停止'),
            ])
              ListTile(
                title: Text(entry.value),
                trailing: state.standby == entry.key
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (value != null) await state.setText('voice.standby', value);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final punctuation = switch (state.voicePunctuation) {
      'space' => '追加空格',
      'none' => '不处理',
      _ => '智能标点',
    };
    return SettingsScaffold(
      title: '语音转文字',
      subtitle: '使用系统语音识别。长按空格或点击工具栏麦克风即可开始；识别文本会插入当前输入框。',
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.mic_none_rounded,
                        color: AppColors.accentDark, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('设备语音识别',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('识别语言：${kVoiceLanguageNames[state.voiceLanguage] ?? state.voiceLanguage}',
                            style: TextStyle(fontSize: 11.5, color: secondary)),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _test(context),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                    child: const Text('测试'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/settings/voice/language'),
                  icon: const Icon(Icons.language_rounded, size: 18),
                  label: const Text('识别语言'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Column(
            children: [
              ToggleRow(
                title: '长按空格启用语音',
                subtitle: '按住空格开始聆听，松开后可在面板中确认',
                value: state.longPressSpaceVoice,
                onChanged: (v) => state.setFlag('voice.longPressSpace', v),
              ),
              const Divider(),
              ToggleRow(
                title: '离线语音',
                subtitle: '优先请求设备离线识别；实际能力取决于系统',
                value: state.offlineSpeech,
                onChanged: (v) => state.setFlag('voice.offline', v),
              ),
              const Divider(),
              ToggleRow(
                title: '显示语音图标',
                subtitle: '在键盘工具栏显示麦克风入口',
                value: state.showVoiceIcon,
                onChanged: (v) => state.setFlag('voice.showIcon', v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ValueRow(
          title: '标点设置',
          value: punctuation,
          icon: Icons.format_size_rounded,
          onTap: () => Navigator.pushNamed(context, '/settings/voice/punctuation'),
        ),
        const SizedBox(height: 4),
        ValueRow(
          title: '录音待机时间',
          value: state.standby == 'never' ? '不自动停止' : '${state.standby} 秒',
          icon: Icons.timer_outlined,
          onTap: () => _pickStandby(context, state),
        ),
        const SizedBox(height: 12),
        InfoBanner(
          text: '语音识别由 iOS/Android 系统提供。模拟器可能没有可用识别服务，此时会明确显示不可用，并允许手动编辑文本。',
          icon: Icons.record_voice_over_outlined,
        ),
      ],
    );
  }
}

class VoiceLanguagePage extends StatelessWidget {
  const VoiceLanguagePage({super.key});

  static const _options = [
    MapEntry('zh_CN', '中文（普通话）'),
    MapEntry('en_US', 'English (US)'),
    MapEntry('zh_HK', '粤语（香港）'),
    MapEntry('zh_TW', '中文（台湾）'),
    MapEntry('ja_JP', '日本語'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return SettingsScaffold(
      title: '识别语言',
      subtitle: '选择系统语音识别使用的语言。中英混说由系统模型决定，不能保证逐句切换。',
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: _options.map((entry) {
              final selected = state.voiceLanguage == entry.key;
              return ListTile(
                title: Text(entry.value,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                subtitle: Text(entry.key,
                    style: TextStyle(fontSize: 10.5, color: secondary)),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: AppColors.accent, size: 20)
                    : null,
                onTap: () async {
                  await state.setVoiceLanguage(entry.key);
                  if (context.mounted) {
                    showToast(context, '识别语言：${entry.value}');
                  }
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        InfoBanner(
          text: '设备未安装对应语言包时，系统会回退到默认语言。若识别失败，请到系统设置安装语音语言包。',
          icon: Icons.translate_rounded,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (context) => const VoiceInputSheet(autoStart: true),
            );
            if (result != null && result.isNotEmpty && context.mounted) {
              showToast(context, '识别结果：$result');
            }
          },
          icon: const Icon(Icons.mic_none_rounded, size: 18),
          label: const Text('用当前语言测试'),
        ),
      ],
    );
  }
}

class VoicePunctuationPage extends StatelessWidget {
  const VoicePunctuationPage({super.key});

  static const _options = [
    ('smart', '智能标点', '根据中英文自动补句号/句点，已有标点不重复添加'),
    ('space', '追加空格', '识别结果后追加一个空格，适合连续口述'),
    ('none', '不处理', '完全保留系统识别的原始文本'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final sample = state.voicePunctuation == 'smart'
        ? '今天的会议改到下午三点。'
        : state.voicePunctuation == 'space'
            ? '今天的会议改到下午三点 '
            : '今天的会议改到下午三点';
    return SettingsScaffold(
      title: '标点设置',
      subtitle: '控制语音识别结果插入时的标点策略。',
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: _options.map((entry) {
              final selected = state.voicePunctuation == entry.$1;
              return ListTile(
                title: Text(entry.$2,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                subtitle: Text(entry.$3,
                    style: TextStyle(fontSize: 11, color: secondary, height: 1.4)),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: AppColors.accent, size: 20)
                    : null,
                onTap: () => state.setVoicePunctuation(entry.$1),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        SettingCard(
          title: '插入效果预览',
          description: '示例：识别文本「今天的会议改到下午三点」',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Text(sample, style: const TextStyle(fontSize: 16, height: 1.6)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (context) => const VoiceInputSheet(autoStart: true),
            );
            if (result != null) {
              if (context.mounted) showToast(context, '识别结果：$result');
            }
          },
          icon: const Icon(Icons.mic_none_rounded, size: 18),
          label: const Text('测试当前标点策略'),
        ),
      ],
    );
  }
}
