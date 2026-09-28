import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_lite/core/app_controller.dart';
import 'package:tieba_lite/core/local_store.dart';
import 'package:tieba_lite/core/models.dart';
import 'package:tieba_lite/core/session_store.dart';
import 'package:tieba_lite/core/settings_store.dart';
import 'package:tieba_lite/features/settings_page.dart';
import 'package:tieba_lite/features/thread_page.dart';
import 'package:tieba_lite/l10n/app_localizations.dart';
import 'package:tieba_lite/platform/glass_accessibility.dart';
import 'package:tieba_lite/theme/app_theme.dart';
import 'package:tieba_lite/widgets/common.dart';
import 'package:tieba_lite/widgets/emoticons.dart';

void main() {
  late AppController app;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final settings = SettingsStore();
    final sessions = SessionStore();
    final local = LocalStore();
    await settings.init();
    await sessions.init();
    await local.init();
    app = AppController(sessions: sessions, settings: settings, local: local);
  });
  tearDown(() => app.dispose());

  Widget host(
    Widget child, {
    double scale = 1,
    bool opaque = false,
    Locale locale = const Locale('en'),
  }) => AppScope(
    controller: app,
    child: ListenableBuilder(
      listenable: app.settings,
      builder: (context, _) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(Brightness.light, app.settings),
        darkTheme: buildAppTheme(Brightness.dark, app.settings),
        themeMode: ThemeMode.system,
        builder: (context, child) => GlassAccessibilityScope(
          reduceTransparency: opaque,
          reduceMotion: opaque,
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: child,
      ),
    ),
  );

  test('appearance upgrade runs once and preserves later choices', () async {
    SharedPreferences.setMockInitialValues({
      'tieba_lite.settings.themeMode': 'light',
      'tieba_lite.settings.customPrimaryColor': 0xFF167D8D,
      'tieba_lite.settings.fontScale': 1.2,
    });
    final first = SettingsStore();
    await first.init();
    expect(first.themeMode, 'system');
    expect(first.fontFamily, 'system');
    expect(first.fontScale, 1.2);
    await first.setString('themeMode', 'dark');
    await first.setString('fontFamily', 'notoSans');
    final restored = SettingsStore();
    await restored.init();
    expect(restored.themeMode, 'dark');
    expect(restored.fontFamily, 'notoSans');
    restored.dispose();
    first.dispose();
  });

  testWidgets('font selection updates existing text and persists', (
    tester,
  ) async {
    await tester.pumpWidget(host(const SettingsPage()));
    await tester.pumpAndSettle();
    final font = find.widgetWithText(DropdownButton<String>, 'System font');
    await tester.ensureVisible(font);
    await tester.tap(font);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noto Sans').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(app.settings.fontFamily, 'notoSans');
    expect(
      Theme.of(tester.element(find.byType(SettingsPage)))
          .textTheme
          .bodyLarge
          ?.fontFamily,
      'NotoSansCJKsc',
    );
    await tester.runAsync(() async {
      final restored = SettingsStore();
      await restored.init();
      expect(restored.fontFamily, 'notoSans');
      restored.dispose();
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass falls back to an opaque control without losing taps', (
    tester,
  ) async {
    var taps = 0;
    Widget control() => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => taps++,
          child: const Text('Continue'),
        ),
      ),
    );
    await tester.pumpWidget(host(control()));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsWidgets);
    await tester.pumpWidget(host(control(), opaque: true));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.text('Continue'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'iOS accessibility notifications update glass while the app is open',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const channel = MethodChannel('org.tblite.flutter/appearance');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'reduceTransparency': true, 'reduceMotion': true},
      );
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });
      await tester.pumpWidget(
        host(
          const GlassAccessibility(
            child: Scaffold(
              body: Center(child: GlassSurface(child: Text('Control'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('changed', {
            'reduceTransparency': false,
            'reduceMotion': false,
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'compact posts retain readable width and actions at large text sizes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var replies = 0;
      Widget post() => PostCard(
        post: const Post(
          id: '1',
          author: UserProfile(name: 'Reader'),
          floor: 2,
          content: [
            ContentPart(
              type: ContentType.text,
              text: 'A short reply, with more room for the content.',
            ),
          ],
        ),
        forum: const Forum(),
        onReply: () => replies++,
      );
      await tester.pumpWidget(
        host(Scaffold(body: ListView(children: [post()]))),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(InlinePostText)).left, 14);
      expect(
        tester.getSize(find.byType(PostCard)).height -
            tester.getSize(find.byType(InlinePostText)).height,
        lessThanOrEqualTo(124),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Reply'));
      expect(replies, 1);
      await tester.binding.setSurfaceSize(const Size(320, 874));
      await tester.pumpWidget(
        host(Scaffold(body: ListView(children: [post()])), scale: 2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Reply'));
      expect(replies, 2);
    },
  );

  testWidgets('system appearance changes live and reading previews render', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const export = bool.fromEnvironment('EXPORT_APPEARANCE_PREVIEWS');
    if (export) {
      await tester.runAsync(() async {
        for (final entry in {
          // Desktop previews approximate iOS system glyphs with the existing asset.
          'Ahem': ['NotoSansCJKsc-Regular.otf'],
          'CupertinoSystemText': ['NotoSansCJKsc-Regular.otf'],
          'CupertinoSystemDisplay': ['NotoSansCJKsc-Regular.otf'],
          'NotoSansCJKsc': ['NotoSansCJKsc-Regular.otf'],
        }.entries) {
          final loader = FontLoader(entry.key);
          for (final file in entry.value) {
            loader.addFont(rootBundle.load('assets/fonts/$file'));
          }
          await loader.load();
        }
        final icons = FontLoader('MaterialIcons');
        icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
    }
    final boundary = GlobalKey();
    await tester.pumpWidget(
      host(
        RepaintBoundary(
          key: boundary,
          child: Builder(
            builder: (context) {
              final text = context.l10n.fontPreview;
              return Scaffold(
                appBar: GlassAppBar(
                  leading: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  title: Text(context.l10n.posts),
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ),
                body: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    for (var i = 1; i <= 4; i++)
                      PostCard(
                        post: Post(
                          id: '$i',
                          floor: i,
                          author: UserProfile(name: 'Reader $i'),
                          createdAt: DateTime(2026, 9, 28, 10, 30),
                          likeCount: i * 3,
                          content: [
                            ContentPart(
                              type: ContentType.text,
                              text: i == 1 ? '$text\n$text' : text,
                            ),
                          ],
                        ),
                        forum: const Forum(),
                        onReply: () {},
                      ),
                  ],
                ),
                bottomNavigationBar: GlassBottomBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(context.l10n.reply),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.bookmark_border_rounded),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        locale: const Locale('zh'),
      ),
    );
    for (final brightness in [
      Brightness.light,
      Brightness.dark,
      Brightness.light,
    ]) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.byType(PostCard).first));
      expect(theme.brightness, brightness);
      expect(
        theme.scaffoldBackgroundColor,
        brightness == Brightness.dark ? Colors.black : Colors.white,
      );
      expect(
        theme.textTheme.bodyLarge?.fontFamily,
        ThemeData(platform: TargetPlatform.iOS).textTheme.bodyLarge?.fontFamily,
      );
      expect(
        theme.textTheme.bodyLarge?.fontFamilyFallback,
        isNot(contains('NotoSansCJKsc')),
      );
      expect(
        theme.textButtonTheme.style?.textStyle?.resolve({})?.fontFamily,
        ThemeData(platform: TargetPlatform.iOS)
            .textTheme
            .labelLarge
            ?.fontFamily,
      );
      expect(tester.takeException(), isNull);
      if (export) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'artifacts/appearance/thread-${brightness.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}
