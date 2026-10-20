import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/features/ai_chat_page.dart';
import 'pages/features/emoji_page.dart';
import 'pages/features/phrases_page.dart';
import 'pages/features/poster_page.dart';
import 'pages/features/recorder_page.dart';
import 'pages/features/text_tools_page.dart';
import 'pages/features/transfer_page.dart';
import 'pages/features/translate_page.dart';
import 'pages/home_page.dart';
import 'pages/keyboard_demo_page.dart';
import 'pages/keyboard_manage_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/settings/auxiliary_page.dart';
import 'pages/settings/clipboard_page.dart';
import 'pages/settings/display_page.dart';
import 'pages/settings/fuzzy_page.dart';
import 'pages/settings/keystroke_page.dart';
import 'pages/settings/migration_page.dart';
import 'pages/settings/more_pages.dart';
import 'pages/settings/plus_page.dart';
import 'pages/settings/privacy_page.dart';
import 'pages/settings/service_page.dart';
import 'pages/settings/standalone_page.dart';
import 'pages/settings/sync_page.dart';
import 'pages/settings/toolbar_page.dart';
import 'pages/settings/voice_pages.dart';
import 'theme.dart';
import 'widgets/common.dart';

class WeTypeApp extends StatelessWidget {
  const WeTypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final mode = switch (state.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      title: '微输入法',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: state.acceptedPrivacy ? '/' : '/onboarding',
      onGenerateRoute: _route,
    );
  }

  static Route<dynamic> _route(RouteSettings settings) {
    final args = settings.arguments;
    Map<String, dynamic> mapArgs() {
      if (args is Map) return Map<String, dynamic>.from(args);
      return const {};
    }

    final page = switch (settings.name) {
      '/' => const HomePage(),
      '/onboarding' => const OnboardingPage(),
      '/keyboard' =>
        KeyboardDemoPage(initialMode: mapArgs()['mode']?.toString() ?? 't9'),
      '/keyboard/manage' => const KeyboardManagePage(),
      '/settings/display' => const DisplaySettingsPage(),
      '/settings/keystroke' => const KeystrokeSettingsPage(),
      '/settings/toolbar' => const ToolbarSettingsPage(),
      '/settings/auxiliary' => const AuxiliarySettingsPage(),
      '/settings/fuzzy' => const FuzzyPinyinPage(),
      '/settings/voice' => const VoiceSettingsPage(),
      '/settings/voice/language' => const VoiceLanguagePage(),
      '/settings/voice/punctuation' => const VoicePunctuationPage(),
      '/settings/plus' => const PlusSettingsPage(),
      '/settings/clipboard' => const ClipboardPage(),
      '/settings/sync' => const SyncPage(),
      '/settings/migration' => const MigrationPage(),
      '/settings/standalone' => const StandalonePage(),
      '/settings/privacy' => const PrivacyPage(),
      '/settings/service' => const ServiceSettingsPage(),
      '/more/desktop' => const DesktopPage(),
      '/more/about' => const AboutPage(),
      '/more/help' => const HelpPage(),
      '/recorder' => const RecorderPage(),
      '/recorder/session' => const RecorderSessionsPage(),
      '/transfer' => const TransferPage(),
      '/ai' => AiChatPage(draft: mapArgs()['draft']?.toString() ?? ''),
      '/tools' => TextToolsPage(
          initialMode: mapArgs()['mode']?.toString() ?? 'polish',
          initialText: mapArgs()['text']?.toString() ?? '',
        ),
      '/translate' =>
        TranslatePage(initialText: mapArgs()['text']?.toString() ?? ''),
      '/poster' => const PosterPage(),
      '/phrases' => const PhrasesPage(),
      '/emoji' => EmojiPage(
          initialTab:
              mapArgs()['tab'] is num ? (mapArgs()['tab'] as num).toInt() : 0),
      _ => _UnknownRoute(name: settings.name ?? ''),
    };
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => page,
    );
  }
}

class _UnknownRoute extends StatelessWidget {
  final String name;
  const _UnknownRoute({required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('页面不存在')),
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: '没有找到 $name',
        subtitle: '这个路由不存在。返回首页继续。',
        action: FilledButton(
          onPressed: () =>
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
          child: const Text('回到首页'),
        ),
      ),
    );
  }
}
