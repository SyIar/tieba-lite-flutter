import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview_ios/flutter_inappwebview_ios.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_lite/platform/baidu_web_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cookieChannel = MethodChannel(
    'com.pichillilorenzo/flutter_inappwebview_cookiemanager',
  );
  const storageChannel = MethodChannel(
    'com.pichillilorenzo/flutter_inappwebview_webstoragemanager',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  var storageUnavailable = false;

  setUpAll(IOSInAppWebViewPlatform.registerWith);
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    storageUnavailable = false;
    messenger.setMockMethodCallHandler(cookieChannel, (call) async {
      expect(call.method, 'deleteAllCookies');
      calls.add('cookies');
      return true;
    });
    messenger.setMockMethodCallHandler(storageChannel, (call) async {
      expect(call.method, 'removeDataModifiedSince');
      final arguments = call.arguments as Map;
      expect(arguments['timestamp'], 0);
      expect(
        arguments['dataTypes'],
        containsAll([
          'WKWebsiteDataTypeCookies',
          'WKWebsiteDataTypeLocalStorage',
          'WKWebsiteDataTypeSessionStorage',
          'WKWebsiteDataTypeIndexedDBDatabases',
        ]),
      );
      calls.add('storage');
      if (storageUnavailable) {
        throw PlatformException(code: 'fixture_storage_unavailable');
      }
      return true;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(cookieChannel, null);
    messenger.setMockMethodCallHandler(storageChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'iOS login initialization uses the actual iOS storage adapter',
    () async {
      final lease = await BaiduWebSessionCoordinator.instance.acquire(
        configure: () async => calls.add('credentials'),
      );
      addTearDown(lease.close);
      expect(lease.active, isTrue);
      expect(calls, ['cookies', 'storage', 'credentials']);
      await lease.close();
      expect(calls, [
        'cookies',
        'storage',
        'credentials',
        'cookies',
        'storage',
      ]);
    },
  );

  test(
    'iOS cleanup failure blocks credentials and permits a clean retry',
    () async {
      storageUnavailable = true;
      await expectLater(
        BaiduWebSessionCoordinator.instance.acquire(
          configure: () async => calls.add('credentials'),
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, isNot(contains('credentials')));
      storageUnavailable = false;
      calls.clear();
      final lease = await BaiduWebSessionCoordinator.instance.acquire(
        configure: () async => calls.add('credentials'),
      );
      addTearDown(lease.close);
      expect(calls, ['cookies', 'storage', 'credentials']);
    },
  );
}
