import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_lite/core/emoticons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every baseline native token has an offline image', () async {
    final catalog = EmoticonCatalog();
    await catalog.load();
    expect(catalog.items, hasLength(58));
    for (final item in catalog.items) {
      expect(item.assetPath, isNotNull, reason: item.id);
      final bytes = await rootBundle.load(item.assetPath!);
      expect(bytes.lengthInBytes, greaterThan(20), reason: item.id);
      expect(catalog.fromToken(item.token)?.id, item.id);
    }
    expect(catalog.byId('image_emoticon')?.id, 'image_emoticon1');
    expect(catalog.byId('image_emoticon31'), isNull);
    expect(catalog.byId('image_emoticon61'), isNotNull);
  });

  test('invalid IDs and token injection cannot enter the catalog', () async {
    final catalog = EmoticonCatalog();
    await catalog.load();
    catalog.register('../private', 'Invalid');
    catalog.register('image_emoticon151', 'Caption)Injected');
    catalog.register('image_emoticon0', 'Invalid ID');
    expect(catalog.items, hasLength(58));
    catalog.register('image_emoticon151', 'Fixture caption');
    expect(catalog.byId('image_emoticon151')?.token, '#(Fixture caption)');
    expect(
      catalog.byId('image_emoticon151')?.url,
      'https://tieba.baidu.com/tb/editor/images/client/image_emoticon151.png',
    );
  });
}
