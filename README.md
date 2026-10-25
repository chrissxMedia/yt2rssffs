# yt2rssffs

Atom feeds for the latest 15 uploads from a YouTube channel. No API key
required.

```sh
dart pub get
dart run bin/yt2rssffs.dart
```

Subscribe to
`http://localhost:8080/feeds/videos.xml?channel_id=UCZs3FO5nPvK9VveqJLIvv_w` in
your feed reader. Only channel IDs are supported.

Set `HOST` and `PORT` to change the default listener, `0.0.0.0:8080`.

```sh
docker build -t yt2rssffs .
docker run --rm -p 8080:8080 yt2rssffs
```

Feeds load on demand and stay cached in memory until one minute past the hour in
UTC, for at most one hour. Reading a feed never extends its expiry. The first
request after expiry refreshes it.
