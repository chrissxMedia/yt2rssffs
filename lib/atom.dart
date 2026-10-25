import 'package:xml/xml.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

String buildFeed(Channel channel, List<Video> videos) {
  final xml = XmlBuilder();
  final epoch = DateTime.utc(1970);
  DateTime? published(Video video) => video.publishDate ?? video.uploadDate;
  final updated = videos
      .map((video) => published(video) ?? epoch)
      .fold(epoch, (latest, date) => date.isAfter(latest) ? date : latest);

  void element(String name, String value) =>
      xml.element(name, nest: () => xml.text(value));
  void date(String name, DateTime value) =>
      element(name, value.toUtc().toIso8601String());
  void author(String name, String url) {
    xml.element(
      'author',
      nest: () {
        element('name', name);
        element('uri', url);
      },
    );
  }

  xml.processing('xml', 'version="1.0" encoding="UTF-8"');
  xml.element(
    'feed',
    namespaces: {
      'http://www.w3.org/2005/Atom': '',
      'http://www.youtube.com/xml/schemas/2015': 'yt',
      'http://search.yahoo.com/mrss/': 'media',
    },
    nest: () {
      element('id', 'yt:channel:${channel.id}');
      element('yt:channelId', channel.id.value);
      element('title', channel.title);
      xml.element(
        'link',
        attributes: {
          'rel': 'self',
          'href': '/feeds/videos.xml?channel_id=${channel.id}',
        },
      );
      xml.element(
        'link',
        attributes: {'rel': 'alternate', 'href': channel.url},
      );
      author(channel.title, channel.url);
      date('updated', updated);
      for (final video in videos) {
        xml.element(
          'entry',
          nest: () {
            element('id', 'yt:video:${video.id}');
            element('yt:videoId', video.id.value);
            element('yt:channelId', video.channelId.value);
            element('title', video.title);
            xml.element(
              'link',
              attributes: {'rel': 'alternate', 'href': video.url},
            );
            author(
              video.author,
              'https://www.youtube.com/channel/${video.channelId}',
            );
            final publishedAt = published(video);
            if (publishedAt != null) date('published', publishedAt);
            date('updated', publishedAt ?? epoch);
            element('summary', video.description);
            xml.element(
              'media:group',
              nest: () {
                element('media:title', video.title);
                xml.element('media:content', attributes: {'url': video.url});
                // YouTube's standard thumbnail URL needs no thumbnail metadata.
                xml.element(
                  'media:thumbnail',
                  attributes: {
                    'url': video.thumbnails.highResUrl,
                    'width': '480',
                    'height': '360',
                  },
                );
                element('media:description', video.description);
              },
            );
          },
        );
      }
    },
  );
  return xml.buildDocument().toXmlString();
}
