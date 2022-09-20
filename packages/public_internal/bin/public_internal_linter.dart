import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

const _annotationPackage =
    'package:public_internal_annotation/src/annotations.dart';
const _annotationClass = 'PublicInternal';

class PublicInternalLinter extends PluginBase {
  @override
  Stream<Lint> getLints(ResolvedUnitResult unit) async* {
    if (unit.path !=
        '/Users/ali/Projects/Flutter/open_source_projects/public_internal/packages/public_internal/example/src/main.dart') {
      return;
    }
    final v = _Visitor(
      unit: unit,
    );
    unit.unit.visitChildren(v);
    for (final lint in v.lints) {
      yield lint;
    }
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  final ResolvedUnitResult unit;
  final lints = <Lint>[];

  _Visitor({
    required this.unit,
  });

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.staticElement;
    if (element is! ClassElement) {
      return;
    }
    final isPublicInternal = _isClassPublicInternal(element);
    if (isPublicInternal) {
      final isInCorrectFolder = _isInCorrectFolder(
        unitPath: unit.path,
        mainClass: element,
      );
      if (!isInCorrectFolder) {
        lints.add(
          Lint(
            code: 'public_internal',
            message: '${node.name} is public internal',
            location: unit.lintLocationFromOffset(
              node.offset,
              length: node.name.length,
            ),
            severity: LintSeverity.warning,
            correction: 'export ${node.name} using export keyword',
            url: 'https://pub.dev/packages/public_internal',
          ),
        );
      }
    }
    super.visitSimpleIdentifier(node);
  }
}

bool _isClassPublicInternal(final ClassElement cls) {
  for (final annotation in cls.metadata) {
    final aElement = annotation.element;
    if (aElement?.location?.components.contains(_annotationPackage) != true) {
      continue;
    }
    final String? className;
    if (aElement is ConstructorElement) {
      className = aElement.displayName;
    } else if (aElement is PropertyAccessorElement) {
      className = aElement.returnType.element2?.displayName;
    } else {
      className = null;
    }
    if (className == _annotationClass) {
      return true;
    }
  }
  return false;
}

bool _isInCorrectFolder({
  required String unitPath,
  required ClassElement mainClass,
}) {
  final unitFile = File(unitPath);
  File? classFile;
  for (final sUri in (mainClass.location?.components ?? [])) {
    final file = File.fromUri(Uri.parse(sUri));
    if (file.existsSync()) {
      classFile = file;
      break;
    }
  }
  if (classFile == null) {
    return true;
  }
  final dir = classFile.parent;
  return unitFile.parent.path.startsWith(dir.path);
}
