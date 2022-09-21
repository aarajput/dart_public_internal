import 'dart:io';

class PublicInternal {
  final int parentStep;

  PublicInternal({
    this.parentStep = 0,
  });
}

class ClassInfo {
  final Directory directory;
  final bool isUnitPathSubset;

  ClassInfo({
    required this.directory,
    required this.isUnitPathSubset,
  });
}
