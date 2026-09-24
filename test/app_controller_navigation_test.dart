import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_lite/core/app_controller.dart';
import 'package:tieba_lite/core/local_store.dart';
import 'package:tieba_lite/core/models.dart';
import 'package:tieba_lite/core/session_store.dart';
import 'package:tieba_lite/core/settings_store.dart';
import 'package:tieba_lite/l10n/app_localizations.dart';
import 'package:tieba_lite/platform/baidu_login_page.dart';

const _homeKey = ValueKey('home');
const _accountRouteKey = ValueKey('previous-account-route');

TiebaSession _fixtureAccount(String id) => TiebaSession(
  userId: id,
  bduss: 'fixture-bduss-$id',
  stoken: 'fixture-stoken-$id',
  user: UserProfile(id: id, name: 'Fixture $id'),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'login discards prior-account routes after identity changed even when it returns false',
    (tester) async => _exerciseLoginNavigation(tester, changeIdentity: true),
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );

  testWidgets(
    'canceling login without identity change preserves the current account route',
    (tester) async => _exerciseLoginNavigation(tester, changeIdentity: false),
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );
}

Future<void> _exerciseLoginNavigation(
  WidgetTester tester, {
  required bool changeIdentity,
}) async {
  final sessions = SessionStore();
  final settings = SettingsStore();
  final local = LocalStore();
  await sessions.init();
  await sessions.saveSession(_fixtureAccount('1001'));
  await sessions.saveSession(_fixtureAccount('1002'), activate: false);
  await settings.init();
  await local.init(accountId: '1001');

  final navigatorKey = GlobalKey<NavigatorState>();
  var navigationResets = 0;
  final controller = AppController(
    sessions: sessions,
    settings: settings,
    local: local,
    onAccountChanged: () {
      navigationResets++;
      navigatorKey.currentState!.popUntil((route) => route.isFirst);
    },
  );
  addTearDown(controller.dispose);
  Future<void>? loginResult;

  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          key: _homeKey,
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    key: _accountRouteKey,
                    body: Center(
                      child: TextButton(
                        onPressed: () {
                          loginResult = controller.login(context);
                        },
                        child: const Text('Open account login'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open account page'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open account page'));
  await tester.pumpAndSettle();
  expect(find.byKey(_accountRouteKey), findsOneWidget);
  expect(controller.defersIncomingLinks, isFalse);

  await tester.tap(find.text('Open account login'));
  await tester.pumpAndSettle();
  expect(find.byType(BaiduLoginPage), findsOneWidget);
  expect(controller.defersIncomingLinks, isTrue);
  expect(navigationResets, 0);

  if (changeIdentity) {
    // Simulate successful session persistence before later WebView cleanup fails.
    await sessions.activate('1002');
    expect(controller.session?.userId, '1002');
    expect(controller.defersIncomingLinks, isTrue);
    expect(navigationResets, 0);
  }

  navigatorKey.currentState!.pop(false);
  await tester.pumpAndSettle();
  await loginResult;
  expect(tester.takeException(), isNull);
  expect(controller.defersIncomingLinks, isFalse);
  expect(find.byType(BaiduLoginPage), findsNothing);
  expect(navigationResets, changeIdentity ? 1 : 0);
  expect(controller.session?.userId, changeIdentity ? '1002' : '1001');
  expect(
    find.byKey(_accountRouteKey),
    changeIdentity ? findsNothing : findsOneWidget,
  );
  expect(navigatorKey.currentState!.canPop(), !changeIdentity);
  if (changeIdentity) expect(find.byKey(_homeKey), findsOneWidget);
  await tester.pumpWidget(const SizedBox.shrink());
}
