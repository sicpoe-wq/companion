// Renders phone-sized screenshots into screenshots/.
// Run: flutter test test/screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:companion/data/characters.dart';
import 'package:companion/models/character.dart';
import 'package:companion/models/emotion.dart';
import 'package:companion/models/message.dart';
import 'package:companion/screens/chat_screen.dart';
import 'package:companion/screens/setup_screen.dart';
import 'package:companion/services/ai_client.dart';
import 'package:companion/services/app_store.dart';
import 'package:companion/services/chat_controller.dart';
import 'package:companion/services/tts_service.dart';
import 'package:companion/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  final fonts = '${Platform.environment['FLUTTER_ROOT'] ?? '/workspace/flutter'}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular', 'Roboto-Medium', 'Roboto-Bold', 'Roboto-Black', 'Roboto-Italic']) {
    final file = File('$fonts/$f.ttf');
    if (file.existsSync()) {
      roboto.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('$fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

Future<ChatController> _controller({
  required Character character,
  required AvatarStyle style,
  required Emotion emotion,
  required List<ChatMessage> messages,
  String scenarioId = 'hangout',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = AppStore(prefs);
  final state = AppState(
    setupDone: true,
    characterId: character.id,
    style: style,
    scenarioId: scenarioId,
    ttsEnabled: false,
    memorySummary: '',
    messages: messages,
  );
  final c = ChatController(
    ai: AiClient(),
    store: store,
    tts: TtsService.noop(),
    state: state,
  );
  c.displayEmotion = emotion;
  return c;
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshots', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});

    final key = GlobalKey();
    Future<void> shot(String name) async {
      // Let the avatar ticker and any images paint.
      await tester.pump();
      await tester.runAsync(() async {
        final ctx = key.currentContext;
        if (ctx != null) {
          final dir = Directory('assets/portraits');
          if (dir.existsSync()) {
            for (final f in dir.listSync()) {
              if (f.path.endsWith('.jpg')) {
                try {
                  await precacheImage(AssetImage(f.path), ctx);
                } catch (_) {}
              }
            }
          }
        }
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('screenshots').createSync();
        File('screenshots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    Widget wrap(Widget child) => RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            home: child,
          ),
        );

    // 1. Setup, cartoon Aria
    final setupCtrl = ChatController(
      ai: AiClient(),
      store: AppStore(await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        return SharedPreferences.getInstance();
      }) as SharedPreferences),
      tts: TtsService.noop(),
      state: AppState.initial(),
    );
    await tester.pumpWidget(wrap(SetupScreen(controller: setupCtrl)));
    await shot('setup_cartoon');

    // 2. Setup, semi-realistic (same screen, toggle)
    setupCtrl.state; // keep
    await tester.tap(find.text('Semi-realistic'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shot('setup_realistic');

    // 3. Chat: cartoon Aria, happy
    final now = DateTime(2026, 11, 11, 12, 30);
    final chatHappy = await tester.runAsync(() => _controller(
          character: aria,
          style: AvatarStyle.cartoon,
          emotion: Emotion.happy,
          messages: [
            ChatMessage(role: ChatRole.assistant, text: aria.greeting, emotion: Emotion.happy, at: now),
            ChatMessage(role: ChatRole.user, text: 'I just found a twenty dollar bill in an old jacket!', at: now),
            ChatMessage(
              role: ChatRole.assistant,
              text: 'Lucky you! A little mystery twenty — now how are we celebrating?',
              emotion: Emotion.happy,
              at: now,
            ),
          ],
        ));
    await tester.pumpWidget(wrap(ChatScreen(controller: chatHappy!)));
    await shot('chat_cartoon_happy');

    // 4. Chat: cartoon Aria, laughing, cafe
    final chatLaugh = await tester.runAsync(() => _controller(
          character: aria,
          style: AvatarStyle.cartoon,
          emotion: Emotion.laughing,
          scenarioId: 'cafe',
          messages: [
            ChatMessage(role: ChatRole.event, text: 'You start: Cafe.', at: now),
            ChatMessage(
              role: ChatRole.assistant,
              text: 'I grabbed us a table by the window. What are you having?',
              emotion: Emotion.happy,
              at: now,
            ),
            ChatMessage(role: ChatRole.user, text: 'Whatever you recommend, and tell me a terrible coffee pun.', at: now),
            ChatMessage(
              role: ChatRole.assistant,
              text: 'Okay, but you asked for it: this espresso is a latte trouble. I regret nothing.',
              emotion: Emotion.laughing,
              at: now,
            ),
          ],
        ));
    await tester.pumpWidget(wrap(ChatScreen(controller: chatLaugh!)));
    await shot('chat_cartoon_laughing');

    // 5. Chat: realistic Julian, thoughtful, walk
    final chatThought = await tester.runAsync(() => _controller(
          character: julian,
          style: AvatarStyle.realistic,
          emotion: Emotion.thoughtful,
          scenarioId: 'walk',
          messages: [
            ChatMessage(role: ChatRole.event, text: 'You start: Go for a walk.', at: now),
            ChatMessage(
              role: ChatRole.assistant,
              text: 'Nice day for it. Lead the way — or I will.',
              emotion: Emotion.happy,
              at: now,
            ),
            ChatMessage(role: ChatRole.user, text: 'Do you ever think about how quiet the trees are?', at: now),
            ChatMessage(
              role: ChatRole.assistant,
              text: "All the time. It's like they're in on something and they're just letting us walk through it.",
              emotion: Emotion.thoughtful,
              at: now,
            ),
          ],
        ));
    await tester.pumpWidget(wrap(ChatScreen(controller: chatThought!)));
    await shot('chat_realistic_thoughtful');

    // 6. Chat: realistic Aria, surprised
    final chatSurp = await tester.runAsync(() => _controller(
          character: aria,
          style: AvatarStyle.realistic,
          emotion: Emotion.surprised,
          messages: [
            ChatMessage(role: ChatRole.assistant, text: aria.greeting, emotion: Emotion.happy, at: now),
            ChatMessage(role: ChatRole.user, text: 'I got tickets to Japan for next month.', at: now),
            ChatMessage(
              role: ChatRole.assistant,
              text: 'Wait — Japan? Next month? That is huge. Tell me everything.',
              emotion: Emotion.surprised,
              at: now,
            ),
          ],
        ));
    await tester.pumpWidget(wrap(ChatScreen(controller: chatSurp!)));
    await shot('chat_realistic_surprised');
  });
}
