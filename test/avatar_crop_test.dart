import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tieba_lite/platform/avatar_crop.dart';

void main() {
  test('cover crop maps viewport pan and zoom into source pixels', () {
    final centered = AvatarCropRegion.fromViewport(
      imageWidth: 800,
      imageHeight: 400,
      viewport: 200,
      zoom: 1,
      offsetX: -100,
      offsetY: 0,
    );
    expect((centered.left, centered.top, centered.size), (200, 0, 400));
    final zoomed = AvatarCropRegion.fromViewport(
      imageWidth: 800,
      imageHeight: 400,
      viewport: 200,
      zoom: 2,
      offsetX: -600,
      offsetY: -200,
    );
    expect((zoomed.left, zoomed.top, zoomed.size), (600, 200, 200));
    expect(
      () => AvatarCropRegion.fromViewport(
        imageWidth: 0,
        imageHeight: 1,
        viewport: 200,
        zoom: 1,
        offsetX: 0,
        offsetY: 0,
      ),
      throwsArgumentError,
    );
  });

  test('crop exports the chosen square as a bounded JPEG avatar', () async {
    final source = img.Image(width: 80, height: 40, numChannels: 3);
    img.fill(source, color: img.ColorRgb8(255, 0, 0));
    img.fillRect(
      source,
      x1: 40,
      y1: 0,
      x2: 79,
      y2: 39,
      color: img.ColorRgb8(0, 0, 255),
    );
    final prepared = await prepareAvatarImage(img.encodePng(source));
    final bytes = await cropAvatarJpeg(
      prepared,
      const AvatarCropRegion(left: 40, top: 0, size: 40),
    );
    final output = img.decodeJpg(bytes)!;
    expect((output.width, output.height), (512, 512));
    final pixel = output.getPixel(256, 256);
    expect(pixel.b, greaterThan(230));
    expect(pixel.r, lessThan(20));
    expect(bytes.length, lessThan(5 * 1024 * 1024));
  });

  test('invalid images and out-of-bounds crops are rejected', () async {
    await expectLater(
      prepareAvatarImage(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    final source = img.Image(width: 10, height: 10, numChannels: 3);
    final prepared = await prepareAvatarImage(img.encodePng(source));
    await expectLater(
      cropAvatarJpeg(
        prepared,
        const AvatarCropRegion(left: 8, top: 0, size: 5),
      ),
      throwsArgumentError,
    );
  });
}
