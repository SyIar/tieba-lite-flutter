import 'dart:convert';
import 'dart:io';
import '../lib/core/proto/PbPage/PbPageRequest.pb.dart';
import '../lib/core/proto/PbPage/PbPageResponse.pb.dart';

void main() {
  final folder = Directory('native/Tests/Fixtures')..createSync(recursive: true);
  final request = {
    'data': {'kz': '123', 'pid': '106', 'pn': 0, 'lz': 1, 'rn': 15, 'with_floor': 1},
  };
  File('${folder.path}/anchor-request.json').writeAsStringSync(jsonEncode(request));
  File('${folder.path}/anchor-request.bin').writeAsBytesSync(
    (PbPageRequest()..mergeFromProto3Json(request)).writeToBuffer(),
  );
  final response = PbPageResponse()..mergeFromProto3Json({
    'data': {
      'forum': {'id': '9', 'name': 'Forum'},
      'thread': {'id': '123', 'title': 'Thread'},
      'page': {'current_page': 7, 'has_more': 0},
      'anti': {'tbs': 'synthetic-tbs'},
      'user_list': [{'id': '42', 'nameShow': 'Author'}],
      'post_list': [{
        'id': '106', 'author_id': '42', 'floor': 7,
        'content': [
          {'type': 9, 'text': 'Text'},
          {'type': 20, 'src': 'https://example.test/image.png', 'bsize': '80,60'},
          {'type': 2, 'text': 'image_emoticon25', 'c': 'Smile'},
          {'type': 10, 'voiceMD5': 'voice-id'},
        ],
      }],
    },
  });
  File('${folder.path}/anchor-response.bin').writeAsBytesSync(response.writeToBuffer());
  stdout.writeln('Exported legacy Dart wire fixtures for native compatibility tests.');
}
