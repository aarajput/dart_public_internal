import 'dart:isolate';

import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/starter.dart';

import 'src/plugin.dart';
import 'src/utils/logging_utils.dart';
import 'src/utils/websocket_plugin_server.dart';

void start(List<String> args, SendPort sendPort) {
  ServerPluginStarter(
    PublicInternalServerPlugin(PhysicalResourceProvider.INSTANCE),
  ).start(sendPort);
}

// only to run analyzer locally for testing, will only work if
// useDebuggingVariant==true in tools/analyzer_plugin/bin/plugin.dart
void main() {
  LoggingUtils.initialize();
  PublicInternalServerPlugin(PhysicalResourceProvider.INSTANCE)
      .start(WebSocketPluginServer());
}
