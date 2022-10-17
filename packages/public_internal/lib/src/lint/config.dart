import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:yaml/yaml.dart';

class Options {
  const Options({
    this.analyzer = const AnalyzerCommonOptions(),
    this.internalPublicOptions = const PublicInternalOptions(),
  });

  factory Options.fromYaml(dynamic yaml) => Options(
        analyzer: AnalyzerCommonOptions.fromYaml(yaml),
        internalPublicOptions: PublicInternalOptions.fromYaml(yaml),
      );

  final AnalyzerCommonOptions analyzer;
  final PublicInternalOptions internalPublicOptions;
}

class AnalyzerCommonOptions {
  static final String _rootKey = 'analyzer';

  const AnalyzerCommonOptions({
    this.exclude = const [],
  });

  final List<String> exclude;

  factory AnalyzerCommonOptions.fromYaml(dynamic yaml) {
    if (yaml is! YamlMap) {
      return AnalyzerCommonOptions();
    }

    final map = yaml[_rootKey];

    if (map is! YamlMap) {
      return AnalyzerCommonOptions();
    }

    final exclude = map['exclude'];

    if (exclude is! YamlList) {
      return AnalyzerCommonOptions();
    }

    return AnalyzerCommonOptions(
      exclude: exclude.value.whereType<String>().toList(),
    );
  }

  @override
  String toString() {
    return '{ exclude: $exclude }';
  }

  @override
  bool operator ==(Object other) =>
      other is AnalyzerCommonOptions &&
      exclude.length == other.exclude.length &&
      exclude.every((e) => other.exclude.contains(e));

  @override
  int get hashCode => exclude.fold(0, (acc, e) => acc ^ e.hashCode);
}

class PublicInternalOptions {
  final AnalysisErrorSeverity severity;

  static final String _rootKey = 'public_internal';

  const PublicInternalOptions({
    this.severity = AnalysisErrorSeverity.WARNING,
  });

  factory PublicInternalOptions.fromYaml(dynamic yaml) {
    final map = yaml[_rootKey];

    if (map is! YamlMap) {
      return PublicInternalOptions();
    }

    final sSeverity = map['severity'].toString().toUpperCase();
    final AnalysisErrorSeverity severity;
    if (sSeverity == AnalysisErrorSeverity.INFO.name) {
      severity = AnalysisErrorSeverity.INFO;
    } else if (sSeverity == AnalysisErrorSeverity.WARNING.name) {
      severity = AnalysisErrorSeverity.WARNING;
    } else if (sSeverity == AnalysisErrorSeverity.ERROR.name) {
      severity = AnalysisErrorSeverity.ERROR;
    } else {
      severity = AnalysisErrorSeverity.WARNING;
    }
    return PublicInternalOptions(
      severity: severity,
    );
  }

  @override
  String toString() {
    return '{ public_internal: $severity }';
  }

  @override
  bool operator ==(Object other) =>
      other is PublicInternalOptions && other.severity == severity;

  @override
  int get hashCode => severity.hashCode;
}
