import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_lite/core/local_store.dart';
import 'package:tieba_lite/platform/image_cache_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'clearing the active image cache preserves draft records and documents',
    () async {
      SharedPreferences.setMockInitialValues({});
      final local = LocalStore();
      await local.init();
      await local.saveDraft(
        ReplyDraft(key: 'fixture', threadId: '2001', content: 'Unsent reply'),
      );
      final temporary = await Directory.systemTemp.createTemp(
        'tieba_cache_test_',
      );
      final document = File('${temporary.path}/draft_image.fixture');
      final metadata = File('${temporary.path}/cache.json');
      await document.writeAsString('Retained document');
      final manager = CacheManager(
        Config(
          'fixture-image-cache',
          repo: JsonCacheInfoRepository.withFile(metadata),
          fileSystem: MemoryCacheSystem(),
        ),
      );
      CachedNetworkImageProvider.defaultCacheManager = manager;
      try {
        final image = await manager.putFile(
          'https://fixture.invalid/image.png',
          Uint8List.fromList([1, 2, 3, 4]),
        );
        expect(await image.exists(), isTrue);
        expect(await ImageCacheActions.sizeBytes(), 4);
        await ImageCacheActions.clear();
        expect(await image.exists(), isFalse);
        expect(await ImageCacheActions.sizeBytes(), 0);
        expect(await document.readAsString(), 'Retained document');
        expect(local.getDraft('fixture')?.content, 'Unsent reply');
      } finally {
        await manager.dispose();
        local.dispose();
        if (await metadata.exists()) await metadata.delete();
        await document.delete();
        await temporary.delete();
      }
    },
  );
}
