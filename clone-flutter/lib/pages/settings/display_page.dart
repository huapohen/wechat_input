import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';

class DisplaySettingsPage extends StatelessWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return SettingsScaffold(
      title: '布局和显示',
      subtitle: '调整候选字、键盘高度、数字键盘与主题。修改会立即应用到应用内键盘。',
      actions: [
        IconButton(
          tooltip: '试用键盘',
          onPressed: () => Navigator.pushNamed(context, '/keyboard'),
          icon: const Icon(Icons.play_circle_outline_rounded, size: 21),
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('候选字大小',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${state.candidateSize.round()} px',
                      style: TextStyle(fontSize: 12, color: secondary)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: dark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("wei'xin'shu'ru'fa",
                        style: TextStyle(fontSize: 11, color: secondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('微输入法',
                            style: TextStyle(
                                fontSize: state.candidateSize,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentDark)),
                        const SizedBox(width: 14),
                        Text('微信',
                            style: TextStyle(
                                fontSize: state.candidateSize - 2,
                                color: dark ? AppColors.darkText : AppColors.text)),
                        const SizedBox(width: 10),
                        Text('未信',
                            style: TextStyle(
                                fontSize: state.candidateSize - 2,
                                color: secondary)),
                      ],
                    ),
                  ],
                ),
              ),
              Slider(
                value: state.candidateSize,
                min: 14,
                max: 26,
                divisions: 12,
                label: state.candidateSize.round().toString(),
                onChanged: (value) => state.setCandidateSize(value),
              ),
              Row(
                children: [
                  Text('A', style: TextStyle(fontSize: 12, color: secondary)),
                  const Spacer(),
                  Text('A', style: TextStyle(fontSize: 20, color: secondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingCard(
          title: '键盘高度',
          description: '手机与平板使用同一比例，平板上限更宽。',
          child: Column(
            children: [
              Row(
                children: [
                  Text('紧凑', style: TextStyle(fontSize: 11, color: secondary)),
                  const Spacer(),
                  Text('${(state.keyboardScale * 100).round()}%',
                      style: TextStyle(fontSize: 12, color: secondary)),
                  const Spacer(),
                  Text('宽松', style: TextStyle(fontSize: 11, color: secondary)),
                ],
              ),
              Slider(
                value: state.keyboardScale,
                min: .75,
                max: 1.35,
                divisions: 12,
                label: '${(state.keyboardScale * 100).round()}%',
                onChanged: (value) => state.setKeyboardScale(value),
              ),
            ],
          ),
        ),
        SettingCard(
          title: '全键盘 · 数字输入',
          description: '选择全键盘上方数字行的形态。',
          child: SegmentedChoice<String>(
            value: state.numberLayout,
            options: const [
              MapEntry('row', '全键盘数字'),
              MapEntry('grid', '九宫格数字'),
            ],
            onChanged: (value) => state.setNumberLayout(value),
          ),
        ),
        SettingCard(
          title: '主题外观',
          description: '跟随系统时由设备的浅色/深色模式决定。',
          child: SegmentedChoice<String>(
            value: state.themeMode,
            options: const [
              MapEntry('system', '跟随系统'),
              MapEntry('light', '浅色'),
              MapEntry('dark', '深色'),
            ],
            onChanged: (value) => state.setThemeMode(value),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Column(
            children: [
              ToggleRow(
                title: '键盘上显示表情键',
                subtitle: '在底行显示表情入口',
                value: state.showEmojiKey,
                onChanged: (v) => state.setFlag('display.emojiKey', v),
              ),
              const Divider(),
              ToggleRow(
                title: '显示工具栏',
                subtitle: '关闭后仅保留候选栏与键盘主体',
                value: state.showToolbar,
                onChanged: (v) => state.setFlag('display.toolbar', v),
              ),
              const Divider(),
              ToggleRow(
                title: '分体键盘',
                subtitle: '平板宽屏时在键盘中央增加握持间隔',
                value: state.splitKeyboard,
                onChanged: (v) => state.setFlag('display.split', v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings/keystroke'),
                icon: const Icon(Icons.volume_up_outlined, size: 18),
                label: const Text('按键效果'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/keyboard/manage'),
                icon: const Icon(Icons.keyboard_outlined, size: 18),
                label: const Text('键盘管理'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
