// Renders phone-sized screenshots into screenshots/.
// Run: flutter test test/screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:companion/data/characters.dart';
import 'package:companion/models/character.dart';
import 'package:companion/models/emotion.dart';
import 'package:companion/models/message.dart';
import 'package:companion/screens/chat_screen.dart';
import 'package:companion/screens/settings_screen.dart';
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
  final fonts =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/workspace/flutter'}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular',
    'Roboto-Medium',
    'Roboto-Bold',
    'Roboto-Black',
    'Roboto-Italic',
  ]) {
    final file = File('$fonts/$f.ttf');
    if (file.existsSync()) {
      roboto.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('$fonts/MaterialIcons-Regular.otf').readAsBytesSync(),
        ),
      ),
    );
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

class _Size {
  final String name;
  final double w, h, dpr;
  const _Size(this.name, this.w, this.h, this.dpr);
}

const _sizes = [
  _Size('360x640', 360, 640, 2),
  _Size('393x852', 393, 852, 2),
  _Size('412x915', 412, 915, 2),
  _Size('704x1024', 704, 1024, 1), // Tim's screenshot size, 1:1
  _Size('352x512', 352, 512, 2), // 704x1024 at 2x — very short screen
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 11, 11, 12, 30);

  for (final sz in _sizes) {
    testWidgets('screenshots ${sz.name}', (tester) async {
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = Size(sz.w * sz.dpr, sz.h * sz.dpr);
      tester.view.devicePixelRatio = sz.dpr;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});

      final key = GlobalKey();
      Future<void> shot(String name) async {
        await tester.pump();
        await tester.runAsync(() async {
          final ctx = key.currentContext;
          if (ctx != null) {
            for (final f in Directory('assets/portraits').listSync()) {
              if (f.path.endsWith('.jpg')) {
                try {
                  await precacheImage(AssetImage(f.path), ctx);
                } catch (_) {}
              }
            }
          }
        });
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: sz.dpr);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('screenshots/${sz.name}').createSync(recursive: true);
          File(
            'screenshots/${sz.name}/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
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

      final setupCtrl = ChatController(
        ai: AiClient(),
        store: AppStore(
          await tester.runAsync(() async {
                SharedPreferences.setMockInitialValues({});
                return SharedPreferences.getInstance();
              })
              as SharedPreferences,
        ),
        tts: TtsService.noop(),
        state: AppState.initial(),
      );
      await tester.pumpWidget(wrap(SetupScreen(controller: setupCtrl)));
      await shot('setup_cartoon');
      await tester.tap(find.text('Semi-realistic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await shot('setup_realistic');

      Future<void> chat(
        String name,
        Character ch,
        AvatarStyle st,
        Emotion e,
        String scene,
        List<ChatMessage> msgs,
      ) async {
        final c = await tester.runAsync(
          () => _controller(
            character: ch,
            style: st,
            emotion: e,
            scenarioId: scene,
            messages: msgs,
          ),
        );
        await tester.pumpWidget(wrap(ChatScreen(controller: c!)));
        await shot(name);
      }

      // Semi-realistic Aria, happy. Includes the exact malformed JSON that
      // v1.0 stored in history, to prove it renders as clean text now.
      await chat(
        'chat_realistic_happy',
        aria,
        AvatarStyle.realistic,
        Emotion.happy,
        'hangout',
        [
          ChatMessage(
            role: ChatRole.assistant,
            text: aria.greeting,
            emotion: Emotion.happy,
            at: now,
          ),
          ChatMessage(
            role: ChatRole.user,
            text: "Let's just hang out for a bit.",
            at: now,
          ),
          ChatMessage.fromJson({
            'role': 'assistant',
            'text':
                '{"{"emotion":"happy","text":"Sounds great! Let\'s just relax and chat.","action":null}',
            'emotion': 'happy',
            'at': now.toIso8601String(),
          }),
        ],
      );
      await chat(
        'chat_realistic_surprised',
        aria,
        AvatarStyle.realistic,
        Emotion.surprised,
        'hangout',
        [
          ChatMessage(
            role: ChatRole.user,
            text: 'I got tickets to Japan for next month.',
            at: now,
          ),
          ChatMessage(
            role: ChatRole.assistant,
            text: 'Wait — Japan? Next month? That is huge. Tell me everything.',
            emotion: Emotion.surprised,
            at: now,
          ),
        ],
      );
      await chat(
        'chat_realistic_julian_thoughtful',
        julian,
        AvatarStyle.realistic,
        Emotion.thoughtful,
        'walk',
        [
          ChatMessage(
            role: ChatRole.event,
            text: 'You start: Go for a walk.',
            at: now,
          ),
          ChatMessage(
            role: ChatRole.user,
            text: 'Do you ever think about how quiet the trees are?',
            at: now,
          ),
          ChatMessage(
            role: ChatRole.assistant,
            text: "All the time. It's like they're in on something.",
            emotion: Emotion.thoughtful,
            at: now,
          ),
        ],
      );
      await chat(
        'chat_cartoon_laughing',
        aria,
        AvatarStyle.cartoon,
        Emotion.laughing,
        'cafe',
        [
          ChatMessage(role: ChatRole.event, text: 'You start: Cafe.', at: now),
          ChatMessage(
            role: ChatRole.user,
            text: 'Tell me a terrible coffee pun.',
            at: now,
          ),
          ChatMessage(
            role: ChatRole.assistant,
            text: 'This espresso is a latte trouble. I regret nothing.',
            emotion: Emotion.laughing,
            at: now,
          ),
        ],
      );
      await chat(
        'chat_cartoon_julian_happy',
        julian,
        AvatarStyle.cartoon,
        Emotion.happy,
        'hangout',
        [
          ChatMessage(
            role: ChatRole.assistant,
            text: julian.greeting,
            emotion: Emotion.happy,
            at: now,
          ),
        ],
      );

      // Close-up of semi-realistic Aria (neck/collar area) on a large phone.
      // Settings: voice + erase options (Aria active, Julian has a saved chat).
      final sc = await tester.runAsync(
        () => _controller(
          character: aria,
          style: AvatarStyle.realistic,
          emotion: Emotion.happy,
          messages: [
            ChatMessage(
              role: ChatRole.assistant,
              text: aria.greeting,
              emotion: Emotion.happy,
              at: now,
            ),
            ChatMessage(role: ChatRole.user, text: 'Hi!', at: now),
          ],
        ),
      );
      sc!.state = sc.state.copyWith(
        saved: {
          'julian': Conversation(
            messages: [
              ChatMessage(role: ChatRole.user, text: 'Hey Julian', at: now),
            ],
          ),
        },
      );
      await tester.pumpWidget(wrap(SettingsScreen(controller: sc)));
      await shot('settings_top');
      await tester.dragUntilVisible(
        find.text('Erase all chats'),
        find.byType(ListView),
        const Offset(0, -250),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await shot('settings_erase');
      await tester.ensureVisible(find.text('Erase chat with Aria'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Erase chat with Aria'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await shot('settings_erase_confirm');
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 400));
    });
  }
}
