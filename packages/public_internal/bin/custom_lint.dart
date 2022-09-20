import 'dart:isolate';

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'public_internal_linter.dart';

void main(List<String> args, SendPort sendPort) {
  startPlugin(sendPort, PublicInternalLinter());
}
