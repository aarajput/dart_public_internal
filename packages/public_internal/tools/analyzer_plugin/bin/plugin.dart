import 'dart:isolate';

import 'package:public_internal/plugin_starter.dart';

void main(List<String> args, SendPort sendPort) {
  start(args, sendPort);
}
