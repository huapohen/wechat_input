import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../keyboard/engine.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class EmojiPage extends StatefulWidget {
  final int initialTab;
  const EmojiPage({super.key, this.initialTab = 0});

  @override
  State<EmojiPage> createState() => _EmojiPageState();
}

class _EmojiPageState extends State<EmojiPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
  KeyboardData? _data;
  String? _error;
  int _category = 0;

  AppState get _state => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    KeyboardData.ensureLoaded().then((value) {
      if (mounted) setState(() => _data = value);
    }).catchError((e) {
      if (mounted) setState(() => _error = '表情数据加载失败：$e');
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _use(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    final state = _state;
    final recent = state.strings('emoji.recent', const []).toList();
    recent.remove(value);
    recent.insert(0, value);
    await state.setStrings('emoji.recent', recent.take(30).toList());
    if (mounted) showToast(context, '已复制 $value');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final recent = state.strings('emoji.recent', const []);
    return Scaffold(
      appBar: AppBar(
        title: const Text('表情'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: dark ? AppColors.darkText : AppColors.text,
          unselectedLabelColor: secondary,
          tabs: const [
            Tab(text: 'Emoji'),
            Tab(text: '颜文字'),
            Tab(text: '符号'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '清除最近使用',
            onPressed: () async {
              await state.setStrings('emoji.recent', const []);
              if (mounted) showToast(context, '已清除最近使用');
            },
            icon: const Icon(Icons.history_toggle_off_rounded, size: 20),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                  message: _error!,
                  onRetry: () {
                    setState(() => _error = null);
                    KeyboardData.ensureLoaded().then((value) {
                      if (mounted) setState(() => _data = value);
                    });
                  },
                ),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _emojiTab(recent, secondary),
                _kaomojiTab(secondary),
                _symbolsTab(secondary),
              ],
            ),
    );
  }

  Widget _emojiTab(List<String> recent, Color secondary) {
    final data = _data;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data.emoji.isEmpty) {
      return const EmptyState(icon: Icons.emoji_emotions_outlined, title: '没有表情数据');
    }
    final index = _category.clamp(0, data.emoji.length - 1);
    return Column(
      children: [
        if (recent.isNotEmpty)
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                const Center(
                    child: Text('最近',
                        style: TextStyle(fontSize: 10, color: AppColors.accentDark))),
                const SizedBox(width: 8),
                ...recent.take(14).map((emoji) => InkWell(
                      onTap: () => _use(emoji),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Center(
                            child: Text(emoji, style: const TextStyle(fontSize: 24))),
                      ),
                    )),
              ],
            ),
          ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: data.emoji.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) => ChoiceChip(
              label: Text(data.emoji[i].name),
              selected: i == index,
              showCheckmark: false,
              onSelected: (_) => setState(() => _category = i),
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 700 ? 14 : 8;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: data.emoji[index].items.length,
              itemBuilder: (context, i) {
                final emoji = data.emoji[index].items[i];
                return InkWell(
                  onTap: () => _use(emoji),
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 27)),
                  ),
                );
              },
            );
          }),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 4, 16, MediaQuery.paddingOf(context).bottom + 8),
          child: Row(
            children: [
              Expanded(
                child: Text('点击即可复制，随后在键盘工具栏「剪贴板」中粘贴。',
                    style: TextStyle(fontSize: 10.5, color: secondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/keyboard'),
                child: const Text('去键盘'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kaomojiTab(Color secondary) {
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('本地颜文字库 · 点击复制',
            style: TextStyle(fontSize: 11, color: secondary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.kaomoji
              .map((item) => InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _use(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Theme.of(context).dividerTheme.color!),
                      ),
                      child: Text(item, style: const TextStyle(fontSize: 15)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        const InfoBanner(
          text: '颜文字在本地生成与复制，不调用 AI，也不会上传。',
          icon: Icons.sentiment_satisfied_alt_rounded,
        ),
      ],
    );
  }

  Widget _symbolsTab(Color secondary) {
    final symbols = [...KeyboardData.punctuation, ...KeyboardData.numbers];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 700 ? 12 : 6;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('常用中文标点与符号 · 点击复制',
                  style: TextStyle(fontSize: 11, color: secondary)),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.25,
              ),
              itemCount: symbols.length,
              itemBuilder: (context, index) => InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _use(symbols[index]),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Theme.of(context).dividerTheme.color!),
                  ),
                  child: Text(symbols[index],
                      style: const TextStyle(fontSize: 19)),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
