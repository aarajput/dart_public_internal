import 'dart:convert';
import 'dart:isolate';

import 'package:public_internal/public_internal.dart' as public_internal;
import 'package:web_socket_channel/io.dart';

// delete .dartServer after changing its value
// and use absolute path in tools/pubspec.yaml for public_internal
const useDebuggingVariant = false;

void main(List<String> args, SendPort sendPort) {
  if (useDebuggingVariant) {
    _PluginProxy(sendPort).start();
  } else {
    public_internal.start(args, sendPort);
  }
}

class _PluginProxy {
  final SendPort sendToAnalysisServer;

  late ReceivePort _receive;
  late IOWebSocketChannel _channel;

  _PluginProxy(this.sendToAnalysisServer);

  Future<void> start() async {
    _channel = IOWebSocketChannel.connect('ws://localhost:9999');
    _receive = ReceivePort();
    sendToAnalysisServer.send(_receive.sendPort);

    _receive.listen((data) {
      // the server will send messages as maps, convert to json
      _channel.sink.add(json.encode(data));
    });

    _channel.stream.listen((data) {
      sendToAnalysisServer.send(json.decode(data as String));
    });
  }
}
