import 'dart:async';

import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/dart/analysis/driver_based_analysis_context.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:glob/glob.dart';
import 'package:yaml/yaml.dart';

import 'lint/config.dart';
import 'lint/rules.dart';
import 'utils/cache.dart';
import 'utils/lint_error.dart';
import 'utils/suppression.dart';

class PublicInternalServerPlugin extends ServerPlugin {
  PublicInternalServerPlugin(ResourceProvider? provider) : super(provider);

  var _filesFromSetPriorityFilesRequest = <String>[];
  Options options = Options();

  @override
  List<String> get fileGlobsToAnalyze => const ['**/*.dart'];

  @override
  String get name => 'public_internal';

  @override
  String get version => '1.0.0-alpha.0';

  @override
  AnalysisDriverGeneric createAnalysisDriver(plugin.ContextRoot contextRoot) {
    final rootPath = contextRoot.root;
    final locator =
        ContextLocator(resourceProvider: resourceProvider).locateRoots(
      includedPaths: [rootPath],
      excludedPaths: [
        ...contextRoot.exclude,
      ],
      optionsFile: contextRoot.optionsFile,
    );

    if (locator.isEmpty) {
      final error = StateError('Unexpected empty context');
      channel.sendNotification(plugin.PluginErrorParams(
        true,
        error.message,
        error.stackTrace.toString(),
      ).toNotification());

      throw error;
    }

    final builder = ContextBuilder(
      resourceProvider: resourceProvider,
    );

    final analysisContext = builder.createContext(contextRoot: locator.first);
    final context = analysisContext as DriverBasedAnalysisContext;
    final dartDriver = context.driver;

    try {
      options = _loadOptions(context.contextRoot.optionsFile);
    } catch (e, s) {
      channel.sendNotification(
        plugin.PluginErrorParams(
          true,
          'Failed to load options: ${e.toString()}',
          s.toString(),
        ).toNotification(),
      );
    }

    runZonedGuarded(
      () {
        dartDriver.results.listen((analysisResult) {
          if (analysisResult is ResolvedUnitResult) {
            _processResult(
              dartDriver,
              analysisResult,
            );
          } else if (analysisResult is ErrorsResult) {
            channel.sendNotification(plugin.PluginErrorParams(
              false,
              'ErrorResult ${analysisResult.path}',
              '',
            ).toNotification());
          } else {
            print('else');
          }
        });
      },
      (Object e, StackTrace stackTrace) {
        channel.sendNotification(
          plugin.PluginErrorParams(
            false,
            'Unexpected error: ${e.toString()}',
            stackTrace.toString(),
          ).toNotification(),
        );
      },
    );

    return dartDriver;
  }

  List<Glob>? _excludeGlobs;
  final Cache<String, bool> _excludeCache = Cache(5000);

  void _processResult(
    AnalysisDriver dartDriver,
    ResolvedUnitResult analysisResult,
  ) {
    final path = analysisResult.path;

    _excludeGlobs ??= options.analyzer.exclude.map((e) => Glob(e)).toList();

    final excluded = _excludeCache.doCache(
      path,
      () => _excludeGlobs!.any((e) => e.matches(path)),
    );

    if (excluded) return;

    try {
      final errors = _check(
        dartDriver,
        analysisResult,
      );
      channel.sendNotification(
        plugin.AnalysisErrorsParams(
          path,
          errors.map((e) => e.error).toList(),
        ).toNotification(),
      );
    } catch (e, stackTrace) {
      channel.sendNotification(
        plugin.PluginErrorParams(
          false,
          e.toString(),
          stackTrace.toString(),
        ).toNotification(),
      );
    }
  }

  List<plugin.AnalysisErrorFixes> _check(
    AnalysisDriver driver,
    ResolvedUnitResult analysisResult,
  ) {
    final errors = <plugin.AnalysisErrorFixes>[];

    final suppression = Suppression(
      content: analysisResult.content,
      lineInfo: analysisResult.unit.lineInfo,
    );

    void onReport(LintError err) {
      if (suppression.isSuppressedLintError(err)) {
        return;
      }

      errors.add(
        err.toAnalysisErrorFixes(
          analysisResult.path,
          analysisResult,
        ),
      );
    }

    findRulesOfPublicInternal(
      analysisResult: analysisResult,
      options: options.internalPublicOptions,
      onReport: onReport,
    );

    return errors;
  }

  Options _loadOptions(File? file) {
    if (file == null) return Options();

    final yaml = loadYaml(file.readAsStringSync());

    return Options.fromYaml(yaml);
  }

  @override
  void contentChanged(String path) {
    super.driverForPath(path)?.addFile(path);
  }

  @override
  Future<plugin.AnalysisSetContextRootsResult> handleAnalysisSetContextRoots(
    plugin.AnalysisSetContextRootsParams parameters,
  ) async {
    final result = await super.handleAnalysisSetContextRoots(parameters);
    _updatePriorityFiles();

    return result;
  }

  @override
  Future<plugin.AnalysisSetPriorityFilesResult> handleAnalysisSetPriorityFiles(
    plugin.AnalysisSetPriorityFilesParams parameters,
  ) async {
    _filesFromSetPriorityFilesRequest = parameters.files;
    _updatePriorityFiles();

    return plugin.AnalysisSetPriorityFilesResult();
  }

  void _updatePriorityFiles() {
    final filesToFullyResolve = {
      ..._filesFromSetPriorityFilesRequest,
      for (final driver2 in driverMap.values)
        ...(driver2 as AnalysisDriver).addedFiles,
    };

    final filesByDriver = <AnalysisDriverGeneric, List<String>>{};
    for (final file in filesToFullyResolve) {
      final contextRoot = contextRootContaining(file);
      if (contextRoot != null) {
        final driver = driverMap[contextRoot];
        if (driver != null) {
          filesByDriver.putIfAbsent(driver, () => <String>[]).add(file);
        }
      }
    }
    filesByDriver.forEach((driver, files) {
      driver.priorityFiles = files;
    });
  }
}
