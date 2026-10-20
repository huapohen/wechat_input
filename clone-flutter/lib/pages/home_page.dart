import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class _CarouselCard {
  final String title;
  final String subtitle;
  final String cta;
  final IconData icon;
  final String route;
  final Map<String, dynamic>? arguments;
  final String? plusItem;
  final List<Color> colors;
  const _CarouselCard({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.icon,
    required this.route,
    this.arguments,
    this.plusItem,
    required this.colors,
  });
}

const List<_CarouselCard> _carousel = [
  _CarouselCard(
    title: '文字整理',
    subtitle: '长文一变清晰，重点一眼看到',
    cta: '立即整理',
    icon: Icons.auto_fix_high_rounded,
    route: '/tools',
    arguments: {'mode': 'polish'},
    plusItem: 'text_polish',
    colors: [Color(0xFF2FC79A), Color(0xFF8BE1C5)],
  ),
  _CarouselCard(
    title: 'AI 录音笔',
    subtitle: '录音实时转文字，自动生成纪要',
    cta: '开始录音',
    icon: Icons.graphic_eq_rounded,
    route: '/recorder',
    colors: [Color(0xFF0E8A68), Color(0xFF4FC5A4)],
  ),
  _CarouselCard(
    title: '多语言自由说',
    subtitle: '中文、英文、方言都能混说',
    cta: '去设置',
    icon: Icons.record_voice_over_rounded,
    route: '/settings/voice/language',
    colors: [Color(0xFF3E8ED0), Color(0xFF9FD6F2)],
  ),
  _CarouselCard(
    title: '表情推荐',
    subtitle: '懂你情绪的表情，一按即达',
    cta: '去看看',
    icon: Icons.emoji_emotions_rounded,
    route: '/emoji',
    arguments: {'tab': 0},
    plusItem: 'sticker',
    colors: [Color(0xFFF0A93B), Color(0xFFF8D59B)],
  ),
  _CarouselCard(
    title: '趣味颜文字',
    subtitle: '给每一句话加一点表情',
    cta: '去使用',
    icon: Icons.sentiment_satisfied_alt_rounded,
    route: '/emoji',
    arguments: {'tab': 1},
    plusItem: 'kaomoji',
    colors: [Color(0xFFD46E9E), Color(0xFFF3BBD3)],
  ),
  _CarouselCard(
    title: '问 AI',
    subtitle: '写作、灵感、问答，随时开问',
    cta: '去提问',
    icon: Icons.auto_awesome_rounded,
    route: '/ai',
    plusItem: 'ask_ai',
    colors: [Color(0xFF5D6FD6), Color(0xFFB2BCF1)],
  ),
  _CarouselCard(
    title: '排版成图',
    subtitle: '把文字排成一张好看的图',
    cta: '去排版',
    icon: Icons.image_rounded,
    route: '/poster',
    plusItem: 'poster',
    colors: [Color(0xFFCA7A4A), Color(0xFFF2C7A8)],
  ),
  _CarouselCard(
    title: '跨设备粘贴传送',
    subtitle: '手机与电脑，复制即达',
    cta: '去连接',
    icon: Icons.devices_rounded,
    route: '/settings/sync',
    colors: [Color(0xFF2E9D94), Color(0xFF9EDDD4)],
  ),
  _CarouselCard(
    title: '灵动表达',
    subtitle: '一句话，换三种说法',
    cta: '试试看',
    icon: Icons.auto_awesome_outlined,
    route: '/tools',
    arguments: {'mode': 'rewrite'},
    plusItem: 'rewrite',
    colors: [Color(0xFF7A63C9), Color(0xFFC9BDF0)],
  ),
];

class _Entry {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Map<String, dynamic>? arguments;
  const _Entry(this.title, this.subtitle, this.icon, this.route, [this.arguments]);
}

const List<_Entry> _settingsEntries = [
  _Entry('布局和显示', '数字键盘、上滑输入、候选字、高度调节等',
      Icons.dashboard_customize_outlined, '/settings/display'),
  _Entry('按键效果', '声音、触感、按键气泡', Icons.volume_up_outlined,
      '/settings/keystroke'),
  _Entry('定制工具栏', '语音、手写找字等常用功能固定在工具栏',
      Icons.auto_awesome_mosaic_outlined, '/settings/toolbar'),
  _Entry('辅助输入', '回车键发送、智能加空格、英文首字母大写等',
      Icons.keyboard_alt_outlined, '/settings/auxiliary'),
  _Entry('跨设备粘贴同步', '文字、图片跨设备粘贴，词库同步',
      Icons.devices_other_outlined, '/settings/sync'),
  _Entry('剪贴板', '快速使用复制内容', Icons.content_paste_outlined,
      '/settings/clipboard'),
  _Entry('键盘管理', '全键盘、九宫格、手写、五笔、双拼、笔画输入',
      Icons.keyboard_outlined, '/keyboard/manage'),
  _Entry('语音转文字', '设置长按空格启用语音', Icons.mic_none_outlined,
      '/settings/voice'),
  _Entry('拼写 Plus', '智能拼写、表情、颜文字等智能推荐',
      Icons.brightness_7_outlined, '/settings/plus'),
  _Entry('单机模式', '无需联网，纯本地使用', Icons.flight_takeoff_outlined,
      '/settings/standalone'),
  _Entry('换机助手', '同步个人词库、设置项、常用语等', Icons.phonelink_setup_outlined,
      '/settings/migration'),
];

const List<_Entry> _moreEntries = [
  _Entry('隐私与权限', '数据与授权一览', Icons.lock_outline_rounded,
      '/settings/privacy'),
  _Entry('电脑版', '在电脑上继续使用', Icons.desktop_windows_outlined,
      '/more/desktop'),
  _Entry('关于', '版本与开放说明', Icons.info_outline_rounded, '/more/about'),
  _Entry('帮助与反馈', '问题排查与建议', Icons.help_outline_rounded, '/more/help'),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final PageController _pageController;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final width = MediaQuery.sizeOf(context).width;
      final count = _carousel.length;
      final next = (_page + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
      if (width < 720) {
        // Keep phone cards at one per view.
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _open(_Entry entry) async {
    await Navigator.pushNamed(context, entry.route, arguments: entry.arguments);
  }

  Future<void> _openCarousel(_CarouselCard card, AppState state) async {
    if (card.plusItem != null) {
      final enabled = state.plusEnabled && state.plusItem(card.plusItem!);
      if (!enabled) {
        final go = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要开启拼写 Plus'),
            content: Text('「${card.title}」属于智能能力，需要先在拼写 Plus 中开启对应开关。'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('去开启')),
            ],
          ),
        );
        if (go == true && mounted) {
          await Navigator.pushNamed(context, '/settings/plus');
        }
        return;
      }
    }
    if (!mounted) return;
    await Navigator.pushNamed(context, card.route, arguments: card.arguments);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 960;
    final header = _HomeHeader(
      state: state,
      onPrivacy: () => Navigator.pushNamed(context, '/onboarding'),
      onService: () => Navigator.pushNamed(context, '/settings/service'),
    );
    final content = _HomeContent(
      state: state,
      pageController: _pageController,
      page: _page,
      header: header,
      onPageChanged: (index) => setState(() => _page = index),
      onCarousel: (card) => _openCarousel(card, state),
      onEntry: _open,
    );
    if (!wide) return Scaffold(body: SafeArea(child: content));
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 0, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: dark ? AppColors.darkBorder : AppColors.border),
                ),
                child: NavigationRail(
                  selectedIndex: 0,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _AppMark(size: 42, dark: dark),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('首页')),
                    NavigationRailDestination(
                        icon: Icon(Icons.keyboard_outlined),
                        selectedIcon: Icon(Icons.keyboard_rounded),
                        label: Text('键盘')),
                    NavigationRailDestination(
                        icon: Icon(Icons.graphic_eq_outlined),
                        selectedIcon: Icon(Icons.graphic_eq_rounded),
                        label: Text('录音')),
                    NavigationRailDestination(
                        icon: Icon(Icons.auto_awesome_outlined),
                        selectedIcon: Icon(Icons.auto_awesome_rounded),
                        label: Text('问 AI')),
                    NavigationRailDestination(
                        icon: Icon(Icons.tune_outlined),
                        selectedIcon: Icon(Icons.tune_rounded),
                        label: Text('设置')),
                  ],
                  onDestinationSelected: (index) {
                    switch (index) {
                      case 1:
                        Navigator.pushNamed(context, '/keyboard');
                      case 2:
                        Navigator.pushNamed(context, '/recorder');
                      case 3:
                        Navigator.pushNamed(context, '/ai');
                      case 4:
                        Navigator.pushNamed(context, '/settings/display');
                    }
                  },
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final AppState state;
  final PageController pageController;
  final int page;
  final Widget header;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<_CarouselCard> onCarousel;
  final ValueChanged<_Entry> onEntry;

  const _HomeContent({
    required this.state,
    required this.pageController,
    required this.page,
    required this.header,
    required this.onPageChanged,
    required this.onCarousel,
    required this.onEntry,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tablet = width >= 720;
        final columns = tablet ? 4 : 2;
        final contentWidth = width.clamp(0, 1180.0);
        final horizontal = tablet ? 28.0 : 20.0;
        final inner = contentWidth - horizontal * 2;
        final gap = tablet ? 14.0 : 12.0;
        final itemWidth = (inner - gap * (columns - 1)) / columns;
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 28),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    header,
                    const SizedBox(height: 18),
                    _Carousel(
                      controller: pageController,
                      current: page,
                      tablet: tablet,
                      state: state,
                      onChanged: onPageChanged,
                      onOpen: onCarousel,
                    ),
                    const SizedBox(height: 8),
                    _Dots(count: _carousel.length, current: page),
                    const SectionHeader('功能'),
                    Row(
                      children: [
                        Expanded(
                          child: _FeatureCard(
                            title: 'AI 录音笔',
                            subtitle: '实时将录音转为清晰、可分享的内容',
                            icon: Icons.graphic_eq_rounded,
                            badge: 'NEW',
                            onTap: () => onEntry(const _Entry(
                                'AI 录音笔', '', Icons.graphic_eq_rounded, '/recorder')),
                          ),
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: _FeatureCard(
                            title: '隔空传送',
                            subtitle: '跨设备发送图片、视频和文件',
                            icon: Icons.send_rounded,
                            onTap: () => onEntry(const _Entry(
                                '隔空传送', '', Icons.send_rounded, '/transfer')),
                          ),
                        ),
                      ],
                    ),
                    SectionHeader(
                      '设置',
                      action: TextButton.icon(
                        onPressed: () => onEntry(const _Entry(
                            '换机助手', '', Icons.phonelink_setup_outlined,
                            '/settings/migration')),
                        icon: const Icon(Icons.phonelink_setup_outlined, size: 17),
                        label: const Text('换机助手'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                          backgroundColor:
                              Theme.of(context).cardTheme.color,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    _Grid(
                      entries: _settingsEntries,
                      columns: columns,
                      itemWidth: itemWidth,
                      gap: gap,
                      onTap: onEntry,
                    ),
                    const SectionHeader('更多'),
                    _Grid(
                      entries: _moreEntries,
                      columns: columns,
                      itemWidth: itemWidth,
                      gap: gap,
                      onTap: onEntry,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        '独立学习复刻 · 与腾讯无关联 · 本地优先',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkSecondary
                              : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  final List<_Entry> entries;
  final int columns;
  final double itemWidth;
  final double gap;
  final ValueChanged<_Entry> onTap;
  const _Grid({
    required this.entries,
    required this.columns,
    required this.itemWidth,
    required this.gap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: entries.map((entry) {
        return SizedBox(
          width: itemWidth,
          child: AppCard(
            onTap: () => onTap(entry),
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(entry.icon,
                    size: 26,
                    color: dark ? AppColors.darkText : AppColors.text),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded,
                        size: 17,
                        color: dark ? AppColors.darkSecondary : AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  entry.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: dark ? AppColors.darkSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final AppState state;
  final VoidCallback onPrivacy;
  final VoidCallback onService;
  const _HomeHeader(
      {required this.state, required this.onPrivacy, required this.onService});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return Row(
      children: [
        const _AppMark(size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('微输入法',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, height: 1.15)),
              const SizedBox(height: 3),
              Text('简洁、好用、打字快',
                  style: TextStyle(fontSize: 12.5, color: secondary)),
              if (state.standalone) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('单机模式',
                      style: TextStyle(fontSize: 10, color: AppColors.accentDark)),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/keyboard'),
          tooltip: '键盘体验',
          icon: const Icon(Icons.keyboard_alt_outlined, size: 21),
          color: secondary,
        ),
        IconButton(
          onPressed: onPrivacy,
          tooltip: '隐私与启用',
          icon: const Icon(Icons.shield_outlined, size: 21),
          color: secondary,
        ),
        IconButton(
          onPressed: onService,
          tooltip: '服务设置',
          icon: const Icon(Icons.settings_outlined, size: 21),
          color: secondary,
        ),
      ],
    );
  }
}

class _AppMark extends StatelessWidget {
  final double size;
  final bool? dark;
  const _AppMark({required this.size, this.dark});

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF25C894), Color(0xFF0E8A68)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: .25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(Icons.keyboard_alt_rounded,
            color: isDark ? Colors.white : Colors.white,
            size: size * .52),
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  final PageController controller;
  final int current;
  final bool tablet;
  final AppState state;
  final ValueChanged<int> onChanged;
  final ValueChanged<_CarouselCard> onOpen;
  const _Carousel({
    required this.controller,
    required this.current,
    required this.tablet,
    required this.state,
    required this.onChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tablet ? 300 : 286,
      child: PageView.builder(
        controller: controller,
        onPageChanged: onChanged,
        padEnds: false,
        itemCount: _carousel.length,
        itemBuilder: (context, index) {
          final card = _carousel[index];
          return Padding(
            padding: EdgeInsets.only(right: tablet ? 14 : 0),
            child: _CarouselCardView(card: card, onOpen: () => onOpen(card)),
          );
        },
      ),
    );
  }
}

class _CarouselCardView extends StatelessWidget {
  final _CarouselCard card;
  final VoidCallback onOpen;
  const _CarouselCardView({required this.card, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: dark ? AppColors.darkBorder : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    card.colors[0].withValues(alpha: dark ? .55 : .18),
                    card.colors[1].withValues(alpha: dark ? .28 : .12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: card.colors[0].withValues(alpha: .14),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: card.colors[1].withValues(alpha: .18),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: (dark ? AppColors.darkSurface : Colors.white)
                            .withValues(alpha: .82),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: card.colors[0].withValues(alpha: .18),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(card.icon, size: 54, color: card.colors[0]),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: (dark ? AppColors.darkSurface : Colors.white)
                            .withValues(alpha: .75),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_carousel.indexOf(card) + 1}/9',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: dark ? AppColors.darkSecondary : AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(card.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: dark ? AppColors.darkSecondary : AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: card.colors[0],
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(card.cta, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;
  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (index) {
          final active = index == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent
                  : (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSecondary
                      : AppColors.muted).withValues(alpha: .5),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: dark ? AppColors.darkText : AppColors.text),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8543E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(badge!,
                      style: const TextStyle(
                          fontSize: 8.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  size: 17,
                  color: dark ? AppColors.darkSecondary : AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 5),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: dark ? AppColors.darkSecondary : AppColors.textSecondary)),
        ],
      ),
    );
  }
}
