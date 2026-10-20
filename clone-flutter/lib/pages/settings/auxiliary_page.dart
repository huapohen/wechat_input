import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class AuxiliarySettingsPage extends StatelessWidget {
  const AuxiliarySettingsPage({super.key});

  Future<void> _clearDictionary(BuildContext context, AppState state) async {
    final ok = await confirmAction(
      context,
      title: '清除个人词典',
      message: '将删除本机学习的词频、固定词与删除记录。词库文件不会受影响。',
      confirm: '清除',
      danger: true,
    );
    if (!ok) return;
    await state.clearPersonalDictionary();
    if (context.mounted) showToast(context, '个人词典已清除');
  }

  Future<void> _restoreDeleted(BuildContext context, AppState state) async {
    final deleted = state.deletedWords.toList();
    if (deleted.isEmpty) {
      showToast(context, '没有待恢复的删除词');
      return;
    }
    for (final word in deleted) {
      await state.restoreWord(word);
    }
    if (context.mounted) showToast(context, '已恢复 ${deleted.length} 个删除词');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final fuzzyCount = state.fuzzyPairs.length;
    return SettingsScaffold(
      title: '辅助输入',
      subtitle: '这些选项影响候选、空格、回车与英文输入的行为。',
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Column(
            children: [
              ToggleRow(
                title: '回车键发送',
                subtitle: '在支持发送的宿主中，回车触发发送而非换行',
                value: state.enterSend,
                onChanged: (v) => state.setFlag('aux.enterSend', v),
              ),
              const Divider(),
              ToggleRow(
                title: '中文与数字自动空格',
                subtitle: '在中文与数字之间补一个空格',
                value: state.autoSpace123,
                onChanged: (v) => state.setFlag('aux.autoSpace123', v),
              ),
              const Divider(),
              ToggleRow(
                title: '中文与英文自动空格',
                subtitle: '在中文与英文之间补一个空格',
                value: state.autoSpaceAbc,
                onChanged: (v) => state.setFlag('aux.autoSpaceAbc', v),
              ),
              const Divider(),
              ToggleRow(
                title: '英文首字母大写',
                subtitle: '英文句首自动大写',
                value: state.capitalize,
                onChanged: (v) => state.setFlag('aux.capitalize', v),
              ),
              const Divider(),
              ToggleRow(
                title: '双击空格输入句号',
                subtitle: '连续空格时把第二个空格替换为「。」',
                value: state.doubleSpacePeriod,
                onChanged: (v) => state.setFlag('aux.doubleSpacePeriod', v),
              ),
              const Divider(),
              ToggleRow(
                title: '英文自动纠错',
                subtitle: '使用本地英文词表给出补全与纠错建议',
                value: state.englishAutoCorrect,
                onChanged: (v) => state.setFlag('aux.englishCorrect', v),
              ),
              const Divider(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ValueRow(
          title: '模糊拼音',
          value: state.fuzzyEnabled ? '已开启 · $fuzzyCount 组' : '已关闭',
          icon: Icons.hearing_outlined,
          onTap: () => Navigator.pushNamed(context, '/settings/fuzzy'),
        ),
        const SizedBox(height: 4),
        const Text('模糊拼音只影响本地候选匹配，不会上传你的输入。',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        SettingCard(
          title: '个人词典',
          description: '候选排序会优先使用你的选择。删除的候选会加入本机黑名单。',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: '学习词',
                      value: '${state.userFreq.length}',
                    ),
                  ),
                  Expanded(
                    child: _Stat(label: '固定词', value: '${state.fixedWords.length}'),
                  ),
                  Expanded(
                    child: _Stat(label: '已删除', value: '${state.deletedWords.length}'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _restoreDeleted(context, state),
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('恢复删除词'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _clearDictionary(context, state),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('清除词典'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoBanner(
          text: '默认回车在应用内键盘中换行；当宿主提供发送动作且「回车键发送」开启时，回车会触发宿主发送。',
          icon: Icons.keyboard_return_rounded,
        ),
        const SizedBox(height: 12),
        Text('当前：${state.enterSend ? '回车发送' : '回车换行'} · ${state.doubleSpacePeriod ? '双击空格句号' : '双击空格不替换'} · ${state.englishAutoCorrect ? '英文纠错开启' : '英文纠错关闭'}',
            style: TextStyle(fontSize: 11, color: secondary)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSecondary
        : AppColors.textSecondary;
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10.5, color: secondary)),
      ],
    );
  }
}
