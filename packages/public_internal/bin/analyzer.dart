import 'package:args/command_runner.dart';
import 'package:public_internal/src/cli/analyze.dart';

Future<void> main(List<String> args) async {
  CommandRunner('public_internal',
      'Linter to make class only accessible within its directory or subdirectories.')
    ..addCommand(AnalyzeCommand())
    ..run(args);
}
