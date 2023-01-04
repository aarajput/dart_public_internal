import 'dart:async';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
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
  final _configs = <String, Config>{};
  AnalysisContextCollection? _contextCollection;

  @override
  String get contactInfo =>
      'https://github.com/aarajput/dart_public_internal/issues';

  @override
  List<String> get fileGlobsToAnalyze => const ['*.dart'];

  @override
  String get name => 'public_internal';

  @override
  String get version => '1.0.0-alpha.0';

  PublicInternalServerPlugin(ResourceProvider provider)
      : super(
          resourceProvider: provider,
        );

  @override
  Future<void> afterNewContextCollection({
    required AnalysisContextCollection contextCollection,
  }) {
    _contextCollection = contextCollection;

    contextCollection.contexts.forEach(_createConfig);

    return super
        .afterNewContextCollection(contextCollection: contextCollection);
  }

  @override
  Future<void> analyzeFile({
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    final isAnalyzed = analysisContext.contextRoot.isAnalyzed(path);
    if (!isAnalyzed) {
      return;
    }

    final rootPath = analysisContext.contextRoot.root.path;

    try {
      final resolvedUnit =
          await analysisContext.currentSession.getResolvedUnit(path);

      if (resolvedUnit is ResolvedUnitResult) {
        final lintErrors = getErrorsForResolvedUnit(
          resolvedUnit,
          _configs[rootPath],
        );

        channel.sendNotification(
          plugin.AnalysisErrorsParams(
            path,
            lintErrors
                .map((lintError) => lintError
                    .toAnalysisErrorFixes(
                      resolvedUnit.path,
                      resolvedUnit,
                    )
                    .error)
                .toList(),
          ).toNotification(),
        );
      } else {
        channel.sendNotification(
          plugin.AnalysisErrorsParams(path, []).toNotification(),
        );
      }
    } on Exception catch (e, stackTrace) {
      channel.sendNotification(
        plugin.PluginErrorParams(false, e.toString(), stackTrace.toString())
            .toNotification(),
      );
    }
  }

  @override
  Future<plugin.EditGetFixesResult> handleEditGetFixes(
    plugin.EditGetFixesParams parameters,
  ) async {
    try {
      final path = parameters.file;
      final analysisContext = _contextCollection?.contextFor(path);
      final resolvedUnit =
          await analysisContext?.currentSession.getResolvedUnit(path);

      if (analysisContext != null && resolvedUnit is ResolvedUnitResult) {
        final analysisErrors = getErrorsForResolvedUnit(
          resolvedUnit,
          _configs[analysisContext.contextRoot.root.path],
        )
            .map((lintError) => lintError.toAnalysisErrorFixes(
                  resolvedUnit.path,
                  resolvedUnit,
                ))
            .where((analysisError) {
          final location = analysisError.error.location;

          return location.file == parameters.file &&
              location.offset <= parameters.offset &&
              parameters.offset <= location.offset + location.length &&
              analysisError.fixes.isNotEmpty;
        }).toList();

        return plugin.EditGetFixesResult(analysisErrors);
      }
    } on Exception catch (e, stackTrace) {
      channel.sendNotification(
        plugin.PluginErrorParams(false, e.toString(), stackTrace.toString())
            .toNotification(),
      );
    }

    return plugin.EditGetFixesResult([]);
  }

  static List<Glob>? _excludeGlobs;
  static final Cache<String, bool> _excludeCache = Cache(5000);

  static List<LintError> getErrorsForResolvedUnit(
    ResolvedUnitResult analysisResult,
    Config? config,
  ) {
    final errors = <LintError>[];
    if (config == null) {
      return [];
    }
    final path = analysisResult.path;
    if (!path.endsWith('.dart')) {
      return [];
    }
    _excludeGlobs ??= config.analyzer.exclude.map((e) => Glob(e)).toList();
    final excluded = _excludeCache.doCache(
      path,
      () => _excludeGlobs!.any((e) => e.matches(path)),
    );

    if (excluded) {
      return [];
    }

    final suppression = Suppression(
      content: analysisResult.content,
      lineInfo: analysisResult.unit.lineInfo,
    );

    void onReport(LintError err) {
      if (suppression.isSuppressedLintError(err)) {
        return;
      }

      errors.add(err);
    }

    findRulesOfPublicInternal(
      analysisResult: analysisResult,
      config: config.internalPublic,
      onReport: onReport,
    );

    return errors;
  }

  void _createConfig(AnalysisContext analysisContext) {
    final rootPath = analysisContext.contextRoot.root.path;
    final file = analysisContext.contextRoot.optionsFile;

    if (file != null && file.exists) {
      try {
        final config = Config.fromYaml(loadYaml(file.readAsStringSync()));
        _configs[rootPath] = config;
      } catch (e, s) {
        channel.sendNotification(
          plugin.PluginErrorParams(
            true,
            'Failed to load options: ${e.toString()}',
            s.toString(),
          ).toNotification(),
        );
      }
    }
  }
}
