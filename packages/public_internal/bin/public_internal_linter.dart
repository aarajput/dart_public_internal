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
    final element = node.staticElement;
    if (element is! ClassElement) {
      return;
    }
    final publicInternalAnnotation = _getPublicInternalAnnotation(element);
    if (publicInternalAnnotation != null) {
      final classInfo = _isInCorrectFolder(
        unitPath: unit.libraryElement.source.uri.path,
        mainClass: element,
        parentStep: publicInternalAnnotation.parentStep,
      );
      if (!classInfo.isUnitPathSubset) {
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
                'Use ${node.name} only in ${classInfo.directory.path} directory or its subdirectories.',
            url: 'https://pub.dev/packages/public_internal',
          ),
        );
      }
    }
    super.visitSimpleIdentifier(node);
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
        if (parentStep != null) {
          return PublicInternal(
            parentStep: parentStep,
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
  required int parentStep,
}) {
  final unitFile = File(unitPath);
  final classFile = File(mainClass.source.uri.path);
  var dir = classFile.parent;
  for (int i = 0; i < parentStep; i++) {
    dir = dir.parent;
  }
  final isSubset = '${unitFile.parent.path}/'.startsWith('${dir.path}/');
  return ClassInfo(
    directory: dir,
    isUnitPathSubset: isSubset,
  );
}
