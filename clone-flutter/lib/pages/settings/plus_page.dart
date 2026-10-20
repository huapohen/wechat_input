import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

const Map<String, (String, String, IconData)> _plusItems = {
  'ask_ai': ('问 AI', '在工具栏与首页打开 AI 对话', Icons.auto_awesome_rounded),
  'smart_spelling': ('智能拼写', '根据上下文调整候选排序', Icons.spellcheck_rounded),
  'spelling_correct': ('拼写纠错', '英文与拼音输入时提示相近拼写', Icons.check_circle_outline_rounded),
  'sticker': ('表情推荐', '根据关键词推荐表情', Icons.emoji_emotions_outlined),
  'small_emoji': ('Emoji 快速输入', '表情面板与快捷插入', Icons.tag_faces_rounded),
  'kaomoji': ('颜文字', '一键插入趣味颜文字', Icons.sentiment_satisfied_alt_rounded),
  'rewrite': ('灵动表达', '一句话生成多种说法', Icons.auto_awesome_outlined),
  'text_polish': ('文字整理', '清理口水词、补全标点', Icons.auto_fix_high_rounded),
  'poster': ('排版成图', '把文字排成可分享的图', Icons.image_outlined),
  'quick_send': ('快捷发送', '候选栏快捷发送当前文本', Icons.send_outlined),
};

class PlusSettingsPage extends StatelessWidget {
  const PlusSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final enabledCount =
        kPlusItems.where((id) => state.plusItem(id)).length;
    return SettingsScaffold(
      title: '拼写 Plus',
      subtitle: '智能能力总开关。关闭后首页相关卡片会先引导你回到这里开启。',
      actions: [
        IconButton(
          tooltip: '恢复默认',
          onPressed: () async {
            await state.setPlusEnabled(true);
            for (final id in kPlusItems) {
              await state.setPlusItem(id, true);
            }
            if (context.mounted) showToast(context, '已恢复默认');
          },
          icon: const Icon(Icons.restart_alt_rounded, size: 21),
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: ToggleRow(
            title: '启用拼写 Plus',
            subtitle: '开启后可使用 AI 文字工具、表情推荐、颜文字与排版成图',
            value: state.plusEnabled,
            onChanged: (v) => state.setPlusEnabled(v),
          ),
        ),
        const SizedBox(height: 10),
        Text('已开启 $enabledCount / ${kPlusItems.length} 项',
            style: TextStyle(fontSize: 11.5, color: secondary)),
        const SizedBox(height: 10),
        ..._plusItems.entries.map((entry) {
          final value = state.plusEnabled && state.plusItem(entry.key);
          final info = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              color: value ? null : (dark ? AppColors.darkSurface : AppColors.surfaceAlt),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: value
                          ? AppColors.accent.withValues(alpha: .12)
                          : secondary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(info.$3,
                        size: 19, color: value ? AppColors.accentDark : secondary),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.$1,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: value ? null : secondary)),
                        const SizedBox(height: 2),
                        Text(info.$2, style: TextStyle(fontSize: 10.5, color: secondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: value,
                    onChanged: state.plusEnabled
                        ? (v) => state.setPlusItem(entry.key, v)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        const Text('快捷入口',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: const Text('文字整理'),
              onPressed: () => Navigator.pushNamed(context, '/tools',
                  arguments: {'mode': 'polish'}),
            ),
            ActionChip(
              avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: const Text('灵动表达'),
              onPressed: () => Navigator.pushNamed(context, '/tools',
                  arguments: {'mode': 'rewrite'}),
            ),
            ActionChip(
              avatar: const Icon(Icons.emoji_emotions_outlined, size: 16),
              label: const Text('表情'),
              onPressed: () => Navigator.pushNamed(context, '/emoji'),
            ),
            ActionChip(
              avatar: const Icon(Icons.image_outlined, size: 16),
              label: const Text('排版成图'),
              onPressed: () => Navigator.pushNamed(context, '/poster'),
            ),
            ActionChip(
              avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('问 AI'),
              onPressed: () => Navigator.pushNamed(context, '/ai'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        InfoBanner(
          text: '这些开关控制界面入口与本地候选行为；AI 请求只在你主动点击生成时发送到自建后端。',
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }
}
