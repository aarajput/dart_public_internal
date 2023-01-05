import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:public_internal/src/lint/config.dart';

import '../utils/lint_error.dart';
import 'models.dart';

const _annotationPackage =
    'package:public_internal_annotation/src/annotations.dart';
const _annotationClass = 'PublicInternal';

void findRulesOfPublicInternal({
  required ResolvedUnitResult resolvedUnit,
  required PublicInternalConfig config,
  required void Function(LintError) onReport,
}) {
  resolvedUnit.unit.visitChildren(
    _Visitor(
      fileUri: resolvedUnit.uri,
      options: config,
      onReport: onReport,
    ),
  );
}

class _Visitor extends RecursiveAstVisitor<void> {
  final Uri fileUri;
  final PublicInternalConfig options;
  final void Function(LintError) onReport;

  _Visitor({
    required this.fileUri,
    required this.options,
    required this.onReport,
  });

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _visitSimpleIdentifier(node);
    super.visitSimpleIdentifier(node);
  }

  void _visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.staticElement;
    if (element is! ClassElement) {
      return;
    }
    final annotation = _getPublicInternalAnnotation(element);
    if (annotation == null) {
      return;
    }
    if (annotation.isStrict) {
      final entities =
          node.parent?.childEntities.map((e) => e.toString()).toList() ?? [];
      if (entities.contains('class')) {
        return;
      }
      if (entities.join('').contains('${node.name}()')) {
        return;
      }
    }
    final classInfo = _isInCorrectFolder(
      unitUri: fileUri,
      mainClass: element,
      annotation: annotation,
    );
    if (!classInfo.isInCorrectDirectory) {
      onReport(LintError(
        message: '${node.name} is public internal.',
        code: 'public_internal',
        errNode: node,
        severity: options.severity,
        correction:
            'Use ${node.name} only in ${classInfo.directory.path} directory${annotation.isStrict ? '.' : ' or its subdirectories.'}',
        url: 'https://pub.dev/packages/public_internal',
      ));
    }
  }
}

PublicInternal? _getPublicInternalAnnotation(final ClassElement cls) {
  for (final annotation in cls.metadata) {
    final aElement = annotation.element;
    if (aElement?.location?.components.contains(_annotationPackage) != true) {
      continue;
    }
    if (aElement is ConstructorElement) {
      if (aElement.displayName == _annotationClass) {
        final parentStep = annotation
            .computeConstantValue()
            ?.getField('parentStep')
            ?.toIntValue();
        final isStrict = annotation
            .computeConstantValue()
            ?.getField('isStrict')
            ?.toBoolValue();
        if (parentStep != null && isStrict != null) {
          return PublicInternal(
            parentStep: parentStep,
            isStrict: isStrict,
          );
        }
      }
    } else if (aElement is PropertyAccessorElement) {
      if (aElement.returnType.element?.displayName == _annotationClass) {
        return PublicInternal();
      }
    }
  }
  return null;
}

ClassInfo _isInCorrectFolder({
  required Uri unitUri,
  required ClassElement mainClass,
  required PublicInternal annotation,
}) {
  final unitFile = File(unitUri.path);
  final classFile = File(mainClass.source.uri.path);
  var dir = classFile.parent;
  for (int i = 0; i < annotation.parentStep; i++) {
    dir = dir.parent;
  }
  final isInCorrectDirectory = annotation.isStrict
      ? '${unitFile.parent.path}/' == '${dir.path}/'
      : '${unitFile.parent.path}/'.startsWith('${dir.path}/');
  return ClassInfo(
    directory: dir,
    isInCorrectDirectory: isInCorrectDirectory,
  );
}
