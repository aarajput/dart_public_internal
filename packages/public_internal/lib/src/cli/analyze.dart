import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/src/dart/analysis/driver_based_analysis_context.dart';
import 'package:args/command_runner.dart';
import 'package:glob/glob.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:public_internal/src/lint/config.dart';
import 'package:yaml/yaml.dart';

import '../../version.dart';
import '../plugin.dart';
import '../utils/logging_utils.dart';

final _logger = Logger('analyze');

class AnalyzeCommand extends Command {
  @override
  String get name => 'analyze';

  @override
  String get description => 'Analyze code for public_internal lint errors';

  @override
  String get invocation => '${runner?.executableName} $name';

  AnalyzeCommand() {
    LoggingUtils.initialize();
    argParser
      ..addSeparator('')
      ..addFlag(
        'version',
        help: 'Reports the version of this tool.',
        negatable: false,
      );
  }

  @override
  Future<void> run() async {
    final results = argResults?['version'];
    if (results == true) {
      _logger.info('public_internal version: $packageVersion');
      return;
    }

    final restArg = [
      if (argResults != null) ...argResults!.rest,
    ];
    if (restArg.isEmpty) {
      restArg.add('./');
    }
    final paths = restArg.map(path.absolute).map(path.normalize).toList();
    final resourceProvider = PhysicalResourceProvider.INSTANCE;

    final contextCollection = AnalysisContextCollectionImpl(
      resourceProvider: resourceProvider,
      includedPaths: paths,
    );
    final errors = <String>[];

    for (final context in contextCollection.contexts) {
      final results = await _checkContext(context);

      for (final result in results) {
        _logger.warning(result);
      }

      errors.addAll(results);
    }
    if (errors.isNotEmpty) {
      _logger.severe('${errors.length} lint error(s) found');
      exit(-1);
    } else {
      _logger.finer('No errors found');
    }
  }

  Future<List<String>> _checkContext(DriverBasedAnalysisContext context) async {
    _logger.info('Analyzing ${context.contextRoot.root.path}');
    final errors = <String>[];

    final config = _loadConfig(context.contextRoot.optionsFile);

    final excludeGlobs = config.analyzer.exclude.map((e) => Glob(e)).toList();

    for (final filePath in context.contextRoot.analyzedFiles()) {
      if (!filePath.endsWith('.dart')) continue;
      if (excludeGlobs.any((e) => e.matches(filePath))) continue;
      if (config.internalPublic.exclude.any((e) => e.matches(filePath))) continue;

      final resolvedUnit = await context.currentSession.getResolvedUnit(filePath);

      if (resolvedUnit is ResolvedUnitResult) {
        final errorFixes = PublicInternalServerPlugin.getErrorsForResolvedUnit(
          resolvedUnit,
          config,
        );
        errors.addAll(
          errorFixes.map(
            (err) => err.toReadableString(
              filePath,
              resolvedUnit.unit,
            ),
          ),
        );
      }
      _logger.config('Analyzed $filePath');
    }

    return errors;
  }

  Config _loadConfig(File? file) {
    if (file == null) return Config();
    return Config.fromYaml(loadYaml(file.readAsStringSync()));
  }
}
