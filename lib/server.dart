import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'feed.dart';

typedef CachedFeed = ({String xml, DateTime expires});

class FeedServer {
  final Future<String> Function(String) load;
  final DateTime Function() now;
  final _cache = <String, CachedFeed>{};
  final _pending = <String, Future<CachedFeed>>{};

  FeedServer({this.load = fetchFeed, this.now = DateTime.now});

  Future<Response> handle(Request request) async {
    if (request.url.path != 'feeds/videos.xml') {
      return Response.notFound('Use /feeds/videos.xml?channel_id=CHANNEL_ID\n');
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      return Response(405, headers: {'allow': 'GET, HEAD'});
    }
    final parameters = request.url.queryParametersAll;
    final ids = parameters['channel_id'];
    if (parameters.length != 1 ||
        ids == null ||
        ids.length != 1 ||
        !ChannelId.validateChannelId(ids.single)) {
      return Response(
        400,
        body:
            'Provide exactly one channel_id, such as '
            'UCZs3FO5nPvK9VveqJLIvv_w.\n',
        headers: {'cache-control': 'no-store'},
      );
    }
    final id = ids.single;
    try {
      final feed = await _getFeed(id);
      final remaining = feed.expires.difference(now().toUtc()).inSeconds;
      return Response.ok(
        request.method == 'HEAD' ? null : feed.xml,
        headers: {
          'content-type': 'application/atom+xml; charset=utf-8',
          'content-length': utf8.encode(feed.xml).length.toString(),
          'cache-control':
              'public, max-age=${remaining < 0 ? 0 : remaining}, '
              'must-revalidate',
          'expires': HttpDate.format(feed.expires),
        },
      );
    } catch (error) {
      // Exception messages can contain upstream URLs and credentials.
      stderr.writeln('Feed refresh failed for $id (${error.runtimeType}).');
      return Response(
        error is TimeoutException ? 504 : 502,
        body: 'Could not fetch this channel from YouTube. Try again later.\n',
        headers: {'cache-control': 'no-store'},
      );
    }
  }

  Future<CachedFeed> _getFeed(String id) async {
    final time = now().toUtc();
    _cache.removeWhere((_, feed) => !time.isBefore(feed.expires));
    final cached = _cache[id];
    if (cached != null) return cached;
    final pending = _pending[id];
    if (pending != null) return pending;

    final refresh = _refresh(id, nextExpiry(time));
    _pending[id] = refresh;
    try {
      return await refresh;
    } finally {
      _pending.remove(id);
    }
  }

  Future<CachedFeed> _refresh(String id, DateTime expires) async {
    final feed = (xml: await load(id), expires: expires);
    _cache[id] = feed;
    return feed;
  }
}

DateTime nextExpiry(DateTime time) {
  final utc = time.toUtc();
  final target = DateTime.utc(utc.year, utc.month, utc.day, utc.hour, 1);
  return utc.isBefore(target) ? target : target.add(const Duration(hours: 1));
}
