import 'dart:isolate';

import 'package:public_internal/public_internal.dart';

void main(List<String> args, SendPort sendPort) {
  start(args, sendPort);
}
