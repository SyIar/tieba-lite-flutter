import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_lite/core/app_controller.dart';
import 'package:tieba_lite/core/local_store.dart';
import 'package:tieba_lite/core/models.dart';
import 'package:tieba_lite/core/proto/FrsPage/FrsPage.pb.dart';
import 'package:tieba_lite/core/session_store.dart';
import 'package:tieba_lite/core/settings_store.dart';
import 'package:tieba_lite/features/forum_page.dart';
import 'package:tieba_lite/features/main_shell.dart';
import 'package:tieba_lite/l10n/app_localizations.dart';

List<int> _forumResponse({required bool signed}) =>
    (FrsPageResponse()..mergeFromProto3Json({
          'data': {
            'forum': {
              'id': '9',
              'name': 'Fixture forum',
              'is_like': 1,
              'member_num': 123,
              'sign_in_info': {
                'user_info': {'is_sign_in': signed ? 1 : 0},
              },
            },
          },
        }))
        .writeToBuffer();

void main() {
  late AppController app;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final sessions = SessionStore();
    final settings = SettingsStore();
    final local = LocalStore();
    await sessions.init();
    await sessions.saveSession(
      const TiebaSession(
        userId: '42',
        bduss: 'fixture-bduss',
        stoken: 'fixture-stoken',
        tbs: 'fixture-tbs',
        user: UserProfile(id: '42', name: 'Fixture user'),
      ),
    );
    await settings.init();
    await local.init(accountId: '42');
    app = AppController(sessions: sessions, settings: settings, local: local);
  });
  tearDown(() => app.dispose());

  Widget host([Widget page = const ForumPage(name: 'Fixture forum')]) =>
      AppScope(
        controller: app,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      );

  Finder checkInButton(String label) =>
      find.widgetWithText(OutlinedButton, label);

  testWidgets(
    'home shows account status and refreshes it after a forum visit',
    (tester) async {
      await tester.runAsync(() => app.settings.setBool('listSingle', true));
      var signed = false;
      var followedRequests = 0;
      app.api.transport.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/frs/page')) {
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: _forumResponse(signed: signed),
                ),
              );
              return;
            }
            Map<String, dynamic> data;
            if (options.path.contains('/getforumlist')) {
              followedRequests++;
              data = {
                'error_code': '0',
                'forum_info': [
                  {
                    'forum_id': '9',
                    'forum_name': 'Fixture forum',
                    'user_level': '5',
                    'is_sign_in': signed ? '1' : '0',
                  },
                ],
              };
            } else {
              expect(options.path, endsWith('/c/c/forum/sign'));
              signed = true;
              data = {
                'error_code': '0',
                'user_info': {'is_sign_in': '1'},
              };
            }
            handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: 200,
                data: jsonEncode(data),
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(host(const HomePage()));
      await tester.pumpAndSettle();
      expect(find.text('Lv.5 · Not checked in'), findsOneWidget);
      expect(find.text('Members 0'), findsNothing);
      expect(followedRequests, 1);
      await tester.tap(find.text('Fixture forum'));
      await tester.pumpAndSettle();
      await tester.tap(checkInButton('Check in'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<OutlinedButton>(checkInButton('Checked in')).onPressed,
        isNull,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Lv.5 · Checked in'), findsOneWidget);
      expect(followedRequests, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('nested server sign state renders a disabled completed button', (
    tester,
  ) async {
    app.api.transport.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, contains('/frs/page'));
          handler.resolve(
            Response<List<int>>(
              requestOptions: options,
              statusCode: 200,
              data: _forumResponse(signed: true),
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(checkInButton('Checked in')).onPressed,
      isNull,
    );
    expect(find.textContaining('Members 123'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'successful sign-in completes before refresh and survives its failure',
    (tester) async {
      var pageRequests = 0;
      RequestInterceptorHandler? signRequest;
      RequestOptions? signOptions;
      RequestInterceptorHandler? refreshRequest;
      RequestOptions? refreshOptions;
      app.api.transport.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/frs/page')) {
              pageRequests++;
              if (pageRequests > 1) {
                refreshRequest = handler;
                refreshOptions = options;
                return;
              }
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: _forumResponse(signed: false),
                ),
              );
            } else {
              expect(options.path, endsWith('/c/c/forum/sign'));
              signRequest = handler;
              signOptions = options;
            }
          },
        ),
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(checkInButton('Check in'));
      await tester.pumpAndSettle();
      expect(signRequest, isNotNull);
      expect(
        tester.widget<OutlinedButton>(checkInButton('Check in')).onPressed,
        isNull,
      );
      signRequest!.resolve(
        Response<String>(
          requestOptions: signOptions!,
          statusCode: 200,
          data: jsonEncode({
            'error_code': '0',
            'user_info': {'is_sign_in': '1'},
          }),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(refreshRequest, isNotNull);
      expect(
        tester.widget<OutlinedButton>(checkInButton('Checked in')).onPressed,
        isNull,
      );
      refreshRequest!.reject(
        DioException(
          requestOptions: refreshOptions!,
          type: DioExceptionType.connectionTimeout,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<OutlinedButton>(checkInButton('Checked in')).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed sign-in remains available and does not reload the forum',
    (tester) async {
      var pageRequests = 0;
      app.api.transport.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/frs/page')) {
              pageRequests++;
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: _forumResponse(signed: false),
                ),
              );
            } else {
              expect(options.path, endsWith('/c/c/forum/sign'));
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  data: jsonEncode({
                    'error_code': '1',
                    'error_msg': 'Fixture sign-in failure',
                  }),
                ),
              );
            }
          },
        ),
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(checkInButton('Check in'));
      await tester.pumpAndSettle();
      expect(pageRequests, 1);
      expect(checkInButton('Checked in'), findsNothing);
      expect(
        tester.widget<OutlinedButton>(checkInButton('Check in')).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
