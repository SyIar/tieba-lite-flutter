import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_lite/app.dart';
import 'package:tieba_lite/core/app_controller.dart';
import 'package:tieba_lite/core/models.dart';
import 'package:tieba_lite/features/main_shell.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
  });
  testWidgets('a fresh install reaches the native guest home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
    await tester.pumpWidget(const TiebaLiteApp());
    for (var index = 0; index < 12; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(MainShell).evaluate().isNotEmpty) break;
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'corrupt account history preserves data and permits guest recovery',
    (tester) async {
      const account = UserProfile(id: '123', name: 'Fixture');
      const session = TiebaSession(
        userId: '123',
        bduss: 'fixture-only',
        stoken: 'fixture-only',
        user: account,
      );
      final namespace = base64Url.encode(utf8.encode('123'));
      final key = 'tieba_lite.local.v1.$namespace';
      SharedPreferences.setMockInitialValues({key: '{broken'});
      FlutterSecureStorage.setMockInitialValues({
        'tieba_lite.accounts.v1': jsonEncode({
          'version': 1,
          'installId': 'fixture-install',
          'activeId': '123',
          'accounts': [
            {'profile': account.toJson(), 'session': session.toJson()},
          ],
        }),
      });
      await tester.pumpWidget(const TiebaLiteApp());
      for (var index = 0; index < 12; index++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(AlertDialog).evaluate().isNotEmpty) break;
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      final controller = AppScope.read(tester.element(find.byType(MainShell)));
      expect(controller.session, isNull);
      expect(controller.accounts.single.id, '123');
      expect((await SharedPreferences.getInstance()).getString(key), '{broken');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
