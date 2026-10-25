import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<List<Video>> getUploads(
  YoutubeExplode youtube,
  YoutubeHttpClient http,
  Channel channel,
) async {
  final uploads = await youtube.channels
      .getUploads(channel.id)
      .take(15)
      .toList();
  if (uploads.isNotEmpty) return uploads;

  // youtube_explode_dart 3.1.0 misses the new uploads playlist layout.
  final page = await http.getString(
    Uri.https('www.youtube.com', '/playlist', {
      'list': 'UU${channel.id.value.substring(2)}',
      'hl': 'en',
    }),
  );
  return parseUploads(page, channel);
}

List<Video> parseUploads(String page, Channel channel) {
  final assignment = RegExp(
    r'(?:var ytInitialData\s*=|window\["ytInitialData"\]\s*=)\s*(\{.*\})\s*;?\s*$',
    dotAll: true,
  );
  final json = html
      .parse(page)
      .querySelectorAll('script')
      .map((script) => assignment.firstMatch(script.text)?.group(1))
      .nonNulls
      .firstOrNull;
  if (json == null) throw const FormatException('Missing uploads data');
  final data = jsonDecode(json);
  final tabs = data['contents']?['twoColumnBrowseResultsRenderer']?['tabs'];
  if (tabs is! List) throw const FormatException('Missing uploads tabs');

  return _lockups(tabs)
      .where((item) => item['contentType'] == 'LOCKUP_CONTENT_TYPE_VIDEO')
      .take(15)
      .map((item) {
        final id = VideoId(item['contentId'] as String);
        final title =
            item['metadata']?['lockupMetadataViewModel']?['title']?['content'];
        return Video(
          id,
          title as String? ?? id.value,
          channel.title,
          channel.id,
          null,
          null,
          null,
          '',
          null,
          ThumbnailSet(id.value),
          null,
          Engagement(0, null, null),
          false,
        );
      })
      .toList();
}

Iterable<Map<String, dynamic>> _lockups(Object? node) sync* {
  if (node is Map<String, dynamic>) {
    final item = node['lockupViewModel'];
    if (item is Map<String, dynamic>) {
      yield item;
    } else {
      for (final child in node.values) {
        yield* _lockups(child);
      }
    }
  } else if (node is List) {
    for (final child in node) {
      yield* _lockups(child);
    }
  }
}
