import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/chat_screen.dart';
import 'screens/setup_screen.dart';
import 'services/ai_client.dart';
import 'services/app_store.dart';
import 'services/chat_controller.dart';
import 'services/tts_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final store = AppStore(prefs);
  final state = store.load();
  final tts = TtsService();
  await tts.init();
  if (state.setupDone) {
    await tts.configure(state.character);
  }
  final controller = ChatController(
    ai: AiClient(),
    store: store,
    tts: tts,
    state: state,
  );
  runApp(CompanionApp(controller: controller));
}

class CompanionApp extends StatelessWidget {
  final ChatController controller;
  const CompanionApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Companion',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.state.setupDone) {
            return SetupScreen(controller: controller);
          }
          return ChatScreen(controller: controller);
        },
      ),
    );
  }
}
