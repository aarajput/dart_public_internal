import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;

class LintError {
  final String message;
  final String code;
  final String? key;
  final AstNode? ctxNode;
  final AstNode errNode;
  final String? correction;
  final String? url;
  final plugin.AnalysisErrorSeverity severity;

  const LintError({
    required this.message,
    required this.code,
    required this.errNode,
    required this.severity,
    this.key,
    this.ctxNode,
    this.correction,
    this.url,
  });

  plugin.AnalysisErrorFixes toAnalysisErrorFixes(
    String file,
    ResolvedUnitResult result,
  ) {
    final location = _toLocation(errNode, file, result.unit);

    return plugin.AnalysisErrorFixes(
      plugin.AnalysisError(
        severity,
        plugin.AnalysisErrorType.LINT,
        location,
        message,
        code,
        correction: correction,
        url: url,
        hasFix: true,
      ),
      fixes: [
        plugin.PrioritizedSourceChange(
          1,
          plugin.SourceChange(
            'Remove',
            edits: [
              plugin.SourceFileEdit(
                location.file,
                result.exists ? 0 : -1,
                edits: [
                  plugin.SourceEdit(
                    location.offset,
                    location.length,
                    '',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  plugin.Location _toLocation(AstNode node, String file, CompilationUnit unit) {
    final lineInfo = unit.lineInfo;
    final begin = node.beginToken.charOffset;
    final end = node.endToken.charEnd;
    final loc = lineInfo.getLocation(begin);
    final locEnd = lineInfo.getLocation(end);

    return plugin.Location(
      file,
      errNode.beginToken.charOffset,
      errNode.length,
      loc.lineNumber,
      loc.columnNumber,
      endLine: locEnd.lineNumber,
      endColumn: locEnd.columnNumber,
    );
  }

  String toReadableString(String file, CompilationUnit unit) {
    final errLoc = _toLocation(errNode, file, unit);

    return '''${errLoc.file} (Line: ${errLoc.startLine}, Col: ${errLoc.startColumn}): $message ($code)

      ${ctxNode?.toSource() ?? errNode.toSource()}
    ''';
  }

  @override
  String toString() {
    return [
      'message: $message',
      'code: $code',
      if (key != null) 'key: $key',
      if (ctxNode != null) 'ctxNode: ${ctxNode!.toSource()}',
      'errNode: ${errNode.toSource()}',
    ].join(', ');
  }
}
