import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_state.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  runApp(AppScope(state: state, child: const WeTypeApp()));
}
