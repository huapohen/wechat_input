import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wechat_input_clone/app.dart';
import 'package:wechat_input_clone/core/app_state.dart';
import 'package:wechat_input_clone/keyboard/engine.dart';
import 'package:wechat_input_clone/keyboard/keyboard.dart';
import 'package:wechat_input_clone/pages/home_page.dart';
import 'package:wechat_input_clone/widgets/common.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  late String prefix;

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 250));
    await binding.takeScreenshot('$prefix-$name');
  }

  Future<void> tapKey(WidgetTester tester, String label) async {
    final finder = find.descendant(
      of: find.byType(InAppKeyboard),
      matching: find.text(label),
    );
    expect(finder, findsWidgets, reason: 'keyboard key $label');
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 120));
  }

  String hostText(WidgetTester tester) {
    final field = tester.widget<TextField>(find.byType(TextField).first);
    return field.controller?.text ?? '';
  }

  testWidgets('page map, keyboard, AI and text tools smoke test', (tester) async {
    SharedPreferences.setMockInitialValues({});
    state = await AppState.load();
    await KeyboardData.ensureLoaded();
    prefix = const String.fromEnvironment('SHOT_PREFIX', defaultValue: '')
        .trim();
    if (prefix.isEmpty) prefix = Platform.isAndroid ? 'android-phone' : 'ios-tablet';

    await tester.pumpWidget(AppScope(state: state, child: const WeTypeApp()));
    await tester.pump(const Duration(milliseconds: 600));

    if (Platform.isAndroid) {
      try {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump(const Duration(milliseconds: 300));
      } catch (e) {
        // Some emulators capture the Flutter surface directly.
        // ignore: avoid_print
        print('convertFlutterSurfaceToImage unavailable: $e');
      }
    }

    // First-run privacy gate.
    await shot(tester, '01-onboarding');
    await tester.scrollUntilVisible(find.byType(Checkbox), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(Checkbox));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.scrollUntilVisible(find.text('开始使用'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('开始使用'));
    await tester.pump(const Duration(milliseconds: 800));

    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, '02-home');
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, '03-home-settings');
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 700));
    await tester.pump(const Duration(milliseconds: 400));

    final navigator = Navigator.of(tester.element(find.byType(HomePage)));

    Future<void> open(String route, {Map<String, dynamic>? arguments}) async {
      navigator.pushNamed(route, arguments: arguments);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('页面不存在'), findsNothing, reason: 'route $route');
    }

    Future<void> close() async {
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    await open('/onboarding');
    await close();

    final routes = <String>[
      '/keyboard/manage',
      '/settings/display',
      '/settings/keystroke',
      '/settings/toolbar',
      '/settings/auxiliary',
      '/settings/fuzzy',
      '/settings/voice',
      '/settings/voice/language',
      '/settings/voice/punctuation',
      '/settings/plus',
      '/settings/clipboard',
      '/settings/sync',
      '/settings/migration',
      '/settings/standalone',
      '/settings/privacy',
      '/settings/service',
      '/more/desktop',
      '/more/about',
      '/more/help',
      '/recorder/session',
      '/transfer',
      '/ai',
      '/tools',
      '/translate',
      '/poster',
      '/phrases',
      '/emoji',
    ];

    for (final route in routes) {
      await open(route);
      if (route == '/settings/display') await shot(tester, '04-display');
      if (route == '/keyboard/manage') await shot(tester, '05-keyboard-manage');
      if (route == '/settings/privacy') await shot(tester, '06-privacy');
      if (route == '/transfer') {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await tester.pump(const Duration(milliseconds: 200));
        await shot(tester, '07-transfer');
      }
      if (route == '/phrases') await shot(tester, '08-phrases');
      if (route == '/emoji') await shot(tester, '09-emoji');
      if (route == '/poster') await shot(tester, '10-poster');
      if (route == '/settings/sync') await shot(tester, '11-sync');
      if (route == '/more/about') await shot(tester, '12-about');
      await close();
    }

    // ------------------------------------------------------------- keyboard
    await open('/keyboard', arguments: {'mode': 't9'});
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(TextField).first);
    await tester.pump(const Duration(milliseconds: 200));
    await shot(tester, '14-keyboard-t9');
    for (final key in ['6', '4', '4', '2', '6']) {
      await tapKey(tester, key);
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('你好'), findsWidgets, reason: 'T9 nihao candidates');
    await shot(tester, '15-t9-candidates');
    await tester.tap(find.text('你好').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(hostText(tester), contains('你好'));

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('切换键盘').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('全键盘拼音').last);
    await tester.pump(const Duration(milliseconds: 500));
    for (final key in ['n', 'i', 'h', 'a', 'o']) {
      await tapKey(tester, key);
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('你好'), findsWidgets, reason: 'QWERTY nihao candidates');
    await shot(tester, '16-qwerty-candidates');
    await tester.tap(find.text('你好').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(hostText(tester), contains('你好'));

    await tester.tap(find.text('中/英').first);
    await tester.pump(const Duration(milliseconds: 400));
    for (final key in ['h', 'e', 'l', 'l', 'o']) {
      await tapKey(tester, key);
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(hostText(tester).toLowerCase(), contains('hello'));
    await shot(tester, '17-english-input');

    await tester.tap(find.text('表情').first);
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, '18-emoji-panel');
    await close();

    // ------------------------------------------------------------------- AI
    await open('/ai');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.enterText(find.byType(TextField).first, '请只回复 OK 两个字母。');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    var replied = false;
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 120));
      final replies = state.chat.where((e) =>
          e.role == 'assistant' && !e.error && e.content.trim().isNotEmpty);
      if (replies.isNotEmpty) {
        replied = true;
        break;
      }
    }
    await shot(tester, '19-ai-chat');
    expect(replied, isTrue,
        reason: 'backend reply missing; last=${state.chat.isEmpty ? 'empty' : state.chat.last.content}');
    await close();

    // ------------------------------------------------------------ text tools
    await open('/tools',
        arguments: {
          'mode': 'polish',
          'text': '嗯那个我们今天呢主要是讨论一下这个项目的进度然后呢大概是在下个月的时候会有一个初步的版本然后风险的话就是人手可能不太够',
        });
    await tester.tap(find.text('整理文字'));
    var polished = false;
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 120));
      if (find.text('整理结果').evaluate().isNotEmpty) {
        polished = true;
        break;
      }
    }
    await shot(tester, '20-text-tools');
    expect(polished, isTrue, reason: 'polish result missing');
    await close();

    expect(state.acceptedPrivacy, isTrue);
    expect(state.phrases.length, greaterThan(0));
    expect(find.byType(HomePage), findsOneWidget);
  });
}
