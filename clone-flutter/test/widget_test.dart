import 'package:flutter_test/flutter_test.dart';
import 'package:wechat_input_clone/keyboard/keyboard.dart';

void main() {
  test('all ten keyboard modes have labels', () {
    expect(kModeNames.length, 10);
    expect(kModeNames['t9'], '九宫格拼音');
    expect(kModeNames['handwrite'], '手写');
  });
}
