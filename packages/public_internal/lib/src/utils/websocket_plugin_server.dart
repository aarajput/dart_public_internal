import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer_plugin/channel/channel.dart';
import 'package:analyzer_plugin/protocol/protocol.dart';
import 'package:logging/logging.dart';

final _logger = Logger('analyzer_proxy');

class WebSocketPluginServer implements PluginCommunicationChannel {
  final dynamic address;
  final int port;

  HttpServer? server;
  WebSocket? _currentClient;

  final StreamController<WebSocket?> _clientStream =
      StreamController.broadcast();

  WebSocketPluginServer({
    dynamic address,
    this.port = 9999,
  }) : address = address ?? InternetAddress.loopbackIPv4 {
    _init();
  }

  Future<void> _init() async {
    server = await HttpServer.bind(address, port);
    _logger.info('listening on $address at port $port');
    server!.transform(WebSocketTransformer()).listen(_handleClientAdded);
  }

  void _handleClientAdded(WebSocket socket) {
    if (_currentClient != null) {
      _logger.severe(
        'ignoring connection attempt because an active client already exists',
      );
      socket.close();
    } else {
      _logger.finer('client connected');
      _currentClient = socket;
      _clientStream.add(_currentClient);
      _currentClient!.done.then((_) {
        _logger.severe('client disconnected');
        _currentClient = null;
        _clientStream.add(null);
      });
    }
  }

  @override
  void close() {
    server?.close(force: true);
  }

  @override
  void listen(
    void Function(Request request) onRequest, {
    Function? onError,
    void Function()? onDone,
  }) {
    final stream = _clientStream.stream;

    // wait until we're connected
    stream.firstWhere((socket) => socket != null).then((_) {
      _currentClient?.listen((data) {
        _logger.info('I: $data');
        onRequest(Request.fromJson(
            json.decode(data as String) as Map<String, dynamic>));
      });
    });
    stream.firstWhere((socket) => socket == null).then((_) => onDone?.call());
  }

  @override
  void sendNotification(Notification notification) {
    _logger.info('N: ${notification.toJson()}');
    _currentClient?.add(json.encode(notification.toJson()));
  }

  @override
  void sendResponse(Response response) {
    _logger.info('O: ${response.toJson()}');
    _currentClient?.add(json.encode(response.toJson()));
  }
}
