import 'dart:async';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'atom.dart';
import 'uploads.dart';

Future<String> fetchFeed(String channelId) async {
  final http = YoutubeHttpClient();
  final youtube = YoutubeExplode(httpClient: http);
  try {
    return await (() async {
      final channel = await youtube.channels.get(channelId);
      final uploads = await getUploads(youtube, http, channel);
      final videos = await Future.wait(
        uploads.map((video) async {
          try {
            return await youtube.videos.get(video.id);
          } on VideoUnplayableException {
            return video;
          } on TransientFailureException {
            return video;
          }
        }),
      );
      return buildFeed(channel, videos);
    })().timeout(const Duration(seconds: 30));
  } finally {
    youtube.close();
  }
}
