import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> image, [Map<String, Object?>? args]) async {
      final env = Platform.environment['CLONE_SHOT_DIR'];
      final dir = Directory(env ?? '../evidence/clone-flutter');
      await dir.create(recursive: true);
      final file = File('${dir.path}/$name.png');
      await file.writeAsBytes(image, flush: true);
      // ignore: avoid_print
      print('screenshot saved: ${file.path}');
      return true;
    },
  );
}
