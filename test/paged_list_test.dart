import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_lite/core/app_controller.dart';
import 'package:tieba_lite/core/local_store.dart';
import 'package:tieba_lite/core/models.dart';
import 'package:tieba_lite/core/session_store.dart';
import 'package:tieba_lite/core/settings_store.dart';
import 'package:tieba_lite/l10n/app_localizations.dart';
import 'package:tieba_lite/features/history_page.dart';
import 'package:tieba_lite/features/main_shell.dart';
import 'package:tieba_lite/platform/deep_links.dart';
import 'package:tieba_lite/widgets/paged_list.dart';

void main() {
  late AppController app;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore();
    final local = LocalStore();
    await settings.init();
    await local.init();
    app = AppController(
      sessions: SessionStore(),
      settings: settings,
      local: local,
    );
  });
  tearDown(() => app.dispose());

  Widget host(Widget child) => AppScope(
    controller: app,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets(
    'reports the first visible item instead of the last loaded item',
    (tester) async {
      final seen = <int>[];
      await tester.pumpWidget(
        host(
          PagedList<int>(
            load: (_) async =>
                PageResult(items: List.generate(20, (index) => index + 1)),
            itemKey: (item) => item,
            onVisibleItemChanged: seen.add,
            itemBuilder: (_, item, _) =>
                SizedBox(height: 100, child: Text('Item $item')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
      expect(seen, [1]);
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
      expect(seen.last, greaterThan(1));
      expect(seen.last, lessThan(10));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('retry after a failed refresh reloads its initial page', (
    tester,
  ) async {
    final pages = <int>[];
    final key = GlobalKey<PagedListState<int>>();
    await tester.pumpWidget(
      host(
        PagedList<int>(
          key: key,
          load: (page) async {
            pages.add(page);
            if (pages.length == 2) throw StateError('Refresh unavailable');
            return PageResult(items: [7], page: page, hasMore: true);
          },
          itemBuilder: (_, item, _) =>
              SizedBox(height: 100, child: Text('Item $item')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await key.currentState!.reload();
    await tester.pumpAndSettle();
    final retryLabel = AppLocalizations.of(
      tester.element(find.byType(PagedList<int>)),
    ).retry;
    await tester.tap(find.text(retryLabel));
    await tester.pumpAndSettle();
    expect(pages, [1, 1, 1]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('anchored pages use the server cursor and deduplicate overlap', (
    tester,
  ) async {
    final pages = <int>[];
    final key = GlobalKey<PagedListState<int>>();
    await tester.pumpWidget(
      host(
        PagedList<int>(
          key: key,
          itemKey: (item) => item,
          load: (page) async {
            pages.add(page);
            return pages.length == 1
                ? const PageResult(items: [21, 22], page: 2, hasMore: true)
                : const PageResult(items: [22, 23], page: 3);
          },
          itemBuilder: (_, item, _) =>
              SizedBox(height: 100, child: Text('Post $item')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await key.currentState!.loadMore();
    await tester.pumpAndSettle();
    expect(pages, [1, 3]);
    expect(find.text('Post 21'), findsOneWidget);
    expect(find.text('Post 22'), findsOneWidget);
    expect(find.text('Post 23'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('forum history removal leaves thread history intact', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await app.local.recordHistory(
        HistoryEntry(threadId: '12', title: 'Thread record', onlyAuthor: true),
      );
      await app.local.recordForum(const Forum(id: '3', name: 'Forum record'));
    });
    await tester.pumpWidget(host(const HistoryPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forums'));
    await tester.pumpAndSettle();
    expect(find.text('Forum record'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from history'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(app.local.forumHistories, isEmpty);
    expect(app.local.recentForums, isEmpty);
    expect(app.local.histories.single.threadId, '12');
    expect(app.local.histories.single.onlyAuthor, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('notification deep links select the requested inbox tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => openIncomingLink(
              context,
              TiebaLink.parse(Uri.parse('tblite://notifications/1'))!,
            ),
            child: const Text('Open inbox'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open inbox'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsPage), findsOneWidget);
    final controller = DefaultTabController.of(
      tester.element(find.byType(TabBar)),
    );
    expect(controller.index, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
