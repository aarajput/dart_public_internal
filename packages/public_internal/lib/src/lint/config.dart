import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:yaml/yaml.dart';

class Config {
  const Config({
    this.analyzer = const AnalyzerCommonConfig(),
    this.internalPublic = const PublicInternalConfig(),
  });

  factory Config.fromYaml(dynamic yaml) => Config(
        analyzer: AnalyzerCommonConfig.fromYaml(yaml),
        internalPublic: PublicInternalConfig.fromYaml(yaml),
      );

  final AnalyzerCommonConfig analyzer;
  final PublicInternalConfig internalPublic;
}

class AnalyzerCommonConfig {
  static final String _rootKey = 'analyzer';

  const AnalyzerCommonConfig({
    this.exclude = const [],
  });

  final List<String> exclude;

  factory AnalyzerCommonConfig.fromYaml(dynamic yaml) {
    if (yaml is! YamlMap) {
      return AnalyzerCommonConfig();
    }

    final map = yaml[_rootKey];

    if (map is! YamlMap) {
      return AnalyzerCommonConfig();
    }

    final exclude = map['exclude'];

    if (exclude is! YamlList) {
      return AnalyzerCommonConfig();
    }

    return AnalyzerCommonConfig(
      exclude: exclude.value.whereType<String>().toList(),
    );
  }

  @override
  String toString() {
    return '{ exclude: $exclude }';
  }

  @override
  bool operator ==(Object other) =>
      other is AnalyzerCommonConfig &&
      exclude.length == other.exclude.length &&
      exclude.every((e) => other.exclude.contains(e));

  @override
  int get hashCode => exclude.fold(0, (acc, e) => acc ^ e.hashCode);
}

class PublicInternalConfig {
  final AnalysisErrorSeverity severity;

  static final String _rootKey = 'public_internal';

  const PublicInternalConfig({
    this.severity = AnalysisErrorSeverity.WARNING,
  });

  factory PublicInternalConfig.fromYaml(dynamic yaml) {
    final map = yaml[_rootKey];

    if (map is! YamlMap) {
      return PublicInternalConfig();
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
    return PublicInternalConfig(
      severity: severity,
    );
  }

  @override
  String toString() {
    return '{ public_internal: $severity }';
  }

  @override
  bool operator ==(Object other) =>
      other is PublicInternalConfig && other.severity == severity;

  @override
  int get hashCode => severity.hashCode;
}
