import 'dart:async';

import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer/src/dart/analysis/driver_based_analysis_context.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:glob/glob.dart';
import 'package:yaml/yaml.dart';

import 'utils/cache.dart';

class FlutterHooksRulesPlugin extends ServerPlugin {
  FlutterHooksRulesPlugin(ResourceProvider? provider) : super(provider);
  // Options options = Options();

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
      // options = _loadOptions(context.contextRoot.optionsFile);
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
              'ErrorResult $analysisResult',
              '',
            ).toNotification());
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

    // _excludeGlobs ??= options.analyzer.exclude.map((e) => Glob(e)).toList();

    final excluded = _excludeCache.doCache(
      path,
          () => _excludeGlobs!.any((e) => e.matches(path)),
    );

    if (excluded) return;

    try {
      // final errors = _check(
      //   dartDriver,
      //   path,
      //   analysisResult,
      // );

      // channel.sendNotification(
      //   plugin.AnalysisErrorsParams(
      //     path,
      //     errors.map((e) => e.error).toList(),
      //   ).toNotification(),
      // );
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
}
