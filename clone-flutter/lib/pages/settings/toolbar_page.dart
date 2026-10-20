import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../keyboard/keyboard.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ToolbarSettingsPage extends StatefulWidget {
  const ToolbarSettingsPage({super.key});

  @override
  State<ToolbarSettingsPage> createState() => _ToolbarSettingsPageState();
}

class _ToolbarSettingsPageState extends State<ToolbarSettingsPage> {
  Future<void> _move(AppState state, String id, int direction) async {
    final order = state.toolbarOrder.toList();
    final index = order.indexOf(id);
    if (index < 0) return;
    final target = index + direction;
    if (target < 0 || target >= order.length) return;
    final item = order.removeAt(index);
    order.insert(target, item);
    await state.setToolbarOrder(order);
  }

  Future<void> _toggle(AppState state, String id, bool visible) async {
    final hidden = state.toolbarHidden.toList();
    if (visible) {
      hidden.remove(id);
    } else {
      if (state.toolbarOrder.where((e) => !hidden.contains(e)).length <= 1) {
        showToast(context, '至少保留一个工具栏按钮');
        return;
      }
      if (!hidden.contains(id)) hidden.add(id);
    }
    await state.setToolbarHidden(hidden);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final order = state.toolbarOrder;
    final hidden = state.toolbarHidden;
    final visible = order.where((e) => !hidden.contains(e)).toList();
    return SettingsScaffold(
      title: '定制工具栏',
      subtitle: '调整键盘工具栏按钮的顺序与可见性。设置会立即反映到应用内键盘。',
      actions: [
        IconButton(
          tooltip: '恢复默认',
          onPressed: () async {
            await state.setToolbarOrder(kDefaultToolbarOrder.split(','));
            await state.setToolbarHidden(const []);
            if (context.mounted) showToast(context, '已恢复默认工具栏');
          },
          icon: const Icon(Icons.restart_alt_rounded, size: 21),
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('预览',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${visible.length} 个按钮',
                      style: TextStyle(fontSize: 11, color: secondary)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.keyboardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final id = visible[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(kToolIcons[id] ?? Icons.circle_outlined,
                            size: 18,
                            color: dark ? AppColors.darkText : AppColors.text),
                        const SizedBox(height: 2),
                        Text(kToolNames[id] ?? id,
                            style: TextStyle(fontSize: 8.5, color: secondary)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...order.map((id) {
          final isVisible = !hidden.contains(id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(
                children: [
                  Icon(kToolIcons[id] ?? Icons.circle_outlined,
                      size: 20, color: AppColors.accentDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kToolNames[id] ?? id,
                            style: TextStyle(
                                fontSize: 14,
                                color: isVisible ? null : secondary,
                                fontWeight: FontWeight.w500)),
                        Text(
                          id == 'voice'
                              ? '打开系统语音识别'
                              : id == 'ai'
                                  ? '把当前文本带到问 AI'
                                  : id == 'translate'
                                      ? '把当前文本带到边写边译'
                                      : id == 'polish'
                                          ? '把当前文本带到文字整理'
                                          : id == 'settings'
                                              ? '打开键盘快捷设置'
                                              : '键盘工具栏动作',
                          style: TextStyle(fontSize: 10.5, color: secondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '上移',
                    onPressed: order.first == id ? null : () => _move(state, id, -1),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: '下移',
                    onPressed: order.last == id ? null : () => _move(state, id, 1),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                  Switch(
                    value: isVisible,
                    onChanged: (v) => _toggle(state, id, v),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        InfoBanner(
          text: '「切换键盘」与「语音」在最窄的手机工具栏上也可能滚动展示；所有按钮点击后都有实际动作。',
          icon: Icons.swipe_outlined,
        ),
      ],
    );
  }
}
