import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:yt2rssffs/server.dart';

Future<void> main() async {
  final env = Platform.environment;
  final port = int.tryParse(env['PORT'] ?? '8080');
  if (port == null || port < 1 || port > 65535) {
    stderr.writeln('PORT must be an integer between 1 and 65535.');
    exitCode = 64;
    return;
  }

  final feeds = FeedServer();
  late final HttpServer server;
  try {
    server = await shelf_io.serve(feeds.handle, env['HOST'] ?? '0.0.0.0', port);
  } catch (error) {
    stderr.writeln('Could not start HTTP server (${error.runtimeType}).');
    exitCode = 1;
    return;
  }
  stdout.writeln('Listening on ${server.address.host}:${server.port}');

  final signals = [ProcessSignal.sigint, ProcessSignal.sigterm];
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  for (final signal in signals) {
    subscriptions.add(
      signal.watch().listen((_) async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await server.close();
      }),
    );
  }
}
