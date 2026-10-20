import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../keyboard/engine.dart';
import '../keyboard/keyboard.dart';
import '../theme.dart';
import '../widgets/common.dart';

const Map<String, String> kModeLayoutFile = {
  't9': 'S1ChineseT9Keyboard.json',
  'qwerty': 'S2ChineseQwertyKeyboard.json',
  'handwrite': 'HandWriteKeyboard.json',
  'stroke': 'S7StrokeT9Keyboard.json',
  'wubi': 'S17WuBiQwertyKeyboard.json',
  'doublepin': 'S9DoublePinQwertyKeyboard.json',
  'english': 'S3EnglishQwertyKeyboard.json',
  'number': 'S4NumberKeyboard.json',
  'symbols': 'S5SymbolKeyboardView.json',
  'emoji': 'S11EmojiKeyboard.json',
};

class KeyboardManagePage extends StatefulWidget {
  const KeyboardManagePage({super.key});

  @override
  State<KeyboardManagePage> createState() => _KeyboardManagePageState();
}

class _KeyboardManagePageState extends State<KeyboardManagePage> {
  KeyboardData? _data;

  @override
  void initState() {
    super.initState();
    KeyboardData.ensureLoaded().then((data) {
      if (mounted) setState(() => _data = data);
    }).catchError((_) {});
  }

  LayoutFact? _factFor(String mode) {
    final data = _data;
    if (data == null) return null;
    final file = kModeLayoutFile[mode];
    for (final fact in data.layouts) {
      if (fact.file == file) return fact;
    }
    return null;
  }

  Future<void> _toggle(AppState state, String mode, bool value) async {
    if (!value && state.enabledModes.length <= 1) {
      showToast(context, '至少保留一种键盘');
      return;
    }
    await state.setModeEnabled(mode, value);
  }

  Future<void> _move(AppState state, String mode, int direction) async {
    final order = state.modeOrder.toList();
    final index = order.indexOf(mode);
    if (index < 0) return;
    final target = index + direction;
    if (target < 0 || target >= order.length) return;
    final item = order.removeAt(index);
    order.insert(target, item);
    await state.setModeOrder(order);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final order = state.modeOrder;
    final enabled = state.enabledModes;
    return SettingsScaffold(
      title: '键盘管理',
      subtitle: '启用或排序键盘。所有键盘共用同一宿主输入框与候选栏。',
      actions: [
        IconButton(
          tooltip: '布局和显示',
          onPressed: () => Navigator.pushNamed(context, '/settings/display'),
          icon: const Icon(Icons.dashboard_customize_outlined, size: 21),
        ),
      ],
      children: [
        InfoBanner(
          text: '当前启用 ${enabled.length} / ${order.length} 种键盘。应用内键盘固定在「键盘体验」与文字工具中显示，不替换系统输入法。',
          icon: Icons.keyboard_outlined,
        ),
        const SizedBox(height: 14),
        ...order.map((mode) {
          final active = enabled.contains(mode);
          final fact = _factFor(mode);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.accent.withValues(alpha: .12)
                          : secondary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(kModeIcons[mode] ?? Icons.keyboard,
                        size: 21,
                        color: active ? AppColors.accentDark : secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(kModeNames[mode] ?? mode,
                                style: const TextStyle(
                                    fontSize: 14.5, fontWeight: FontWeight.w600)),
                            if (mode == 't9') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSoft,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('默认',
                                    style: TextStyle(
                                        fontSize: 8.5, color: AppColors.accentDark)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          fact == null
                              ? '参考布局加载中…'
                              : '参考：${fact.rows} 行 · ${fact.keys} 键 · 源布局 ${fact.file}',
                          style: TextStyle(fontSize: 10.5, color: secondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '上移',
                    onPressed: order.first == mode ? null : () => _move(state, mode, -1),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: '下移',
                    onPressed: order.last == mode ? null : () => _move(state, mode, 1),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                  Switch(
                    value: active,
                    onChanged: (v) => _toggle(state, mode, v),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/keyboard'),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('试用当前键盘'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings/toolbar'),
                icon: const Icon(Icons.auto_awesome_mosaic_outlined, size: 18),
                label: const Text('定制工具栏'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '说明：布局事实来自共享规格（行列与键数），视觉、候选与交互为本项目独立实现。手写为轻量方向模板识别，仅覆盖常用字。',
          style: TextStyle(fontSize: 11, color: secondary, height: 1.55),
        ),
      ],
    );
  }
}
