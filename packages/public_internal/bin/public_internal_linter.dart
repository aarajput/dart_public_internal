import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'models.dart';

const _annotationPackage =
    'package:public_internal_annotation/src/annotations.dart';
const _annotationClass = 'PublicInternal';

class PublicInternalLinter extends PluginBase {
  @override
  Stream<Lint> getLints(ResolvedUnitResult unit) async* {
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
      unitPath: unit.libraryElement.source.uri.path,
      mainClass: element,
      annotation: annotation,
    );
    if (!classInfo.isInCorrectDirectory) {
      lints.add(
        Lint(
          code: 'public_internal',
          message: '${node.name} is public internal.',
          location: unit.lintLocationFromOffset(
            node.offset,
            length: node.name.length,
          ),
          severity: LintSeverity.warning,
          correction:
              'Use ${node.name} only in ${classInfo.directory.path} directory${annotation.isStrict ? '.' : ' or its subdirectories.'}',
          url: 'https://pub.dev/packages/public_internal',
        ),
      );
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
      if (aElement.returnType.element2?.displayName == _annotationClass) {
        return PublicInternal();
      }
    }
  }
  return null;
}

ClassInfo _isInCorrectFolder({
  required String unitPath,
  required ClassElement mainClass,
  required PublicInternal annotation,
}) {
  final unitFile = File(unitPath);
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
