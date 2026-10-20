import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wechat_input_clone/core/app_state.dart';
import 'package:wechat_input_clone/keyboard/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  late KeyboardData data;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    state = await AppState.load();
    data = await KeyboardData.ensureLoaded();
  });

  test('pinyin lookup returns a real phrase for nihao', () {
    final candidates = data.pinyinCandidates('nihao', state);
    expect(candidates.map((e) => e.text), contains('你好'));
  });

  test('T9 digit sequence 64426 maps to nihao phrase', () {
    final candidates = data.t9Candidates('64426', state);
    expect(candidates.map((e) => e.text), contains('你好'));
  });

  test('fuzzy pinyin expands zong to zhong candidates', () {
    final candidates = data.pinyinCandidates('zong', state);
    expect(candidates.map((e) => e.text), contains('中'));
  });

  test('wubi code a yields common characters', () {
    final candidates = data.wubiCandidates('a', state);
    expect(candidates, isNotEmpty);
    expect(candidates.map((e) => e.text), contains('工'));
  });

  test('stroke prefix h returns candidates', () {
    final candidates = data.strokeCandidates('h', state);
    expect(candidates, isNotEmpty);
  });

  test('xiaobe double pinyin nihc decodes to nihao phrase', () {
    expect(data.decodeDoublePin('nihc'), 'nihao');
    final candidates = data.doublePinCandidates('nihc', state);
    expect(candidates.map((e) => e.text), contains('你好'));
  });

  test('fixed words rank first and deleted words disappear', () async {
    await state.fixWord('nihao', '你hao');
    final fixed = data.pinyinCandidates('nihao', state);
    expect(fixed.first.text, '你hao');
    await state.deleteWord('你hao');
    final afterDelete = data.pinyinCandidates('nihao', state);
    expect(afterDelete.map((e) => e.text), isNot(contains('你hao')));
  });
}
