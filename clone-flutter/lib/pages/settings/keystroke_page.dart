import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class KeystrokeSettingsPage extends StatefulWidget {
  const KeystrokeSettingsPage({super.key});

  @override
  State<KeystrokeSettingsPage> createState() => _KeystrokeSettingsPageState();
}

class _KeystrokeSettingsPageState extends State<KeystrokeSettingsPage> {
  bool _demoPressed = false;

  Future<void> _test(AppState state) async {
    setState(() => _demoPressed = true);
    if (state.keySound) SystemSound.play(SystemSoundType.click);
    if (state.keyVibrate) {
      if (state.vibrateLevel > .75) {
        await HapticFeedback.mediumImpact();
      } else if (state.vibrateLevel > .4) {
        await HapticFeedback.lightImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    }
    await Future.delayed(const Duration(milliseconds: 160));
    if (mounted) setState(() => _demoPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return SettingsScaffold(
      title: '按键效果',
      subtitle: '声音与触感只作用于应用内键盘；在系统键盘中是否生效取决于平台设置。',
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: double.infinity,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _demoPressed
                      ? AppColors.accentSoft
                      : (dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _demoPressed
                          ? AppColors.accent
                          : (dark ? AppColors.darkBorder : AppColors.border)),
                ),
                child: Text(
                  _demoPressed ? 'A' : '按键预览',
                  style: TextStyle(
                    fontSize: _demoPressed ? 30 : 14,
                    fontWeight: FontWeight.w600,
                    color: _demoPressed ? AppColors.accentDark : secondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _test(state),
                  icon: const Icon(Icons.touch_app_outlined, size: 19),
                  label: const Text('测试按键效果'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              ToggleRow(
                title: '按键声音',
                subtitle: '使用系统点击音，不附带音频资源',
                value: state.keySound,
                onChanged: (v) => state.setFlag('keys.sound', v),
              ),
              const Divider(),
              ToggleRow(
                title: '按键振动',
                subtitle: '使用系统触感反馈',
                value: state.keyVibrate,
                onChanged: (v) => state.setFlag('keys.vibrate', v),
              ),
              if (state.keyVibrate)
                Row(
                  children: [
                    Text('轻', style: TextStyle(fontSize: 11, color: secondary)),
                    Expanded(
                      child: Slider(
                        value: state.vibrateLevel,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        label: state.vibrateLevel < .4
                            ? '轻'
                            : state.vibrateLevel < .75
                                ? '中'
                                : '强',
                        onChanged: (v) => state.setNumber('keys.vibrateLevel', v),
                      ),
                    ),
                    Text('强', style: TextStyle(fontSize: 11, color: secondary)),
                  ],
                ),
              const Divider(),
              ToggleRow(
                title: '按键气泡',
                subtitle: '按下时按键轻微放大并改变底色',
                value: state.keyBubble,
                onChanged: (v) => state.setFlag('keys.bubble', v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/keyboard'),
          icon: const Icon(Icons.keyboard_outlined, size: 18),
          label: const Text('在键盘中试用'),
        ),
        const SizedBox(height: 12),
        InfoBanner(
          text: '按键声音与触感是应用内效果。系统输入法的声音/振动由系统设置控制，本应用不会修改它。',
          icon: Icons.info_outline_rounded,
        ),
      ],
    );
  }
}
