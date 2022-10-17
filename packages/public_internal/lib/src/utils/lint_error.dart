import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
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

  const LintError({
    required this.message,
    required this.code,
    required this.errNode,
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
        plugin.AnalysisErrorSeverity.WARNING,
        plugin.AnalysisErrorType.LINT,
        location,
        message,
        code,
        correction: correction,
        url: url,
      ),
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

int? _findNearestComma(
  Token beginToken,
  Token endToken,
  Token? Function(Token?) next,
) {
  Token? token = beginToken;

  while ((token = next(token)) != endToken) {
    switch (token?.type) {
      case TokenType.COMMA:
        return token!.charOffset;

      case TokenType.MULTI_LINE_COMMENT:
      case TokenType.SINGLE_LINE_COMMENT:
        continue;

      default:
        return null;
    }
  }

  return null;
}

int? _findNextComma(Token beginToken, Token endToken) {
  return _findNearestComma(beginToken, endToken, (token) => token?.next);
}

int? _findLastComma(Token beginToken, Token endToken) {
  return _findNearestComma(beginToken, endToken, (token) => token?.previous);
}
