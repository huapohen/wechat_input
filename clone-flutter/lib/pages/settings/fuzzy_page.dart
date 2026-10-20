import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

const Map<String, String> _fuzzyLabels = {
  'zh_z': 'zh ↔ z（知 ↔ 资）',
  'ch_c': 'ch ↔ c（吃 ↔ 词）',
  'sh_s': 'sh ↔ s（是 ↔ 四）',
  'n_l': 'n ↔ l（南 ↔ 兰）',
  'r_l': 'r ↔ l（热 ↔ 乐）',
  'an_ang': 'an ↔ ang（安 ↔ 昂）',
  'en_eng': 'en ↔ eng（恩 ↔ 鞥）',
  'in_ing': 'in ↔ ing（因 ↔ 英）',
  'ian_iang': 'ian ↔ iang（先 ↔ 香）',
  'uan_uang': 'uan ↔ uang（关 ↔ 光）',
  'un_ong': 'un ↔ ong（论 ↔ 龙）',
  'ong_eng': 'ong ↔ eng（红 ↔ 横）',
  'ai_ei': 'ai ↔ ei（白 ↔ 北）',
  'u_v': 'u ↔ ü（路 ↔ 绿）',
};

class FuzzyPinyinPage extends StatelessWidget {
  const FuzzyPinyinPage({super.key});

  Future<void> _setAll(AppState state, bool enabled) async {
    for (final pair in kAllFuzzyPairs) {
      await state.setFuzzyPair(pair, enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return SettingsScaffold(
      title: '模糊拼音',
      subtitle: '开启后，相近读音也能命中候选。例如输入 zhong 仍可候选「中」，输入 nihao 可匹配南/兰混淆。',
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (value) => _setAll(state, value == 'all'),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'all', child: Text('全选')),
            PopupMenuItem(value: 'none', child: Text('全部关闭')),
          ],
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: ToggleRow(
            title: '启用模糊拼音',
            subtitle: '总开关；关闭后各组选择仍会保留',
            value: state.fuzzyEnabled,
            onChanged: (v) => state.setFlag('fuzzy.enabled', v),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('已启用 ${state.fuzzyPairs.length} / ${kAllFuzzyPairs.length} 组',
                style: TextStyle(fontSize: 12, color: secondary)),
            const Spacer(),
            TextButton(
              onPressed: () => _setAll(state, true),
              child: const Text('全选'),
            ),
            TextButton(
              onPressed: () => _setAll(state, false),
              child: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...kAllFuzzyPairs.map((pair) {
          final enabled = state.fuzzyPairs.contains(pair);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Opacity(
              opacity: state.fuzzyEnabled ? 1 : .55,
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fuzzyLabels[pair] ?? pair,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w500)),
                          Text('组 ID：$pair',
                              style: TextStyle(fontSize: 9.5, color: secondary)),
                        ],
                      ),
                    ),
                    Switch(
                      value: enabled,
                      onChanged: state.fuzzyEnabled
                          ? (v) => state.setFuzzyPair(pair, v)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/keyboard'),
          icon: const Icon(Icons.keyboard_outlined, size: 18),
          label: const Text('在键盘中试用'),
        ),
        const SizedBox(height: 12),
        InfoBanner(
          text: '模糊匹配会扩大候选范围；若你不希望相近读音干扰，可只保留常用的 zh/z、ch/c、sh/s。',
          icon: Icons.info_outline_rounded,
        ),
      ],
    );
  }
}
