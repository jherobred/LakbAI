import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai/ai_service.dart';
import 'app.dart';
import 'core/app_state.dart';
import 'knowledge/kb.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final app = await AppState.load();
  await KnowledgeBase.load();
  // Model loading continues in the background; the UI never waits on it.
  await AiService.instance.init(app);
  runApp(LakbAIApp(state: app));
}
