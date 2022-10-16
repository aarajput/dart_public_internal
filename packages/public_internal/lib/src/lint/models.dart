import 'dart:io';

class PublicInternal {
  final int parentStep;
  final bool isStrict;

  PublicInternal({
    this.parentStep = 0,
    this.isStrict = false,
  });
}

class ClassInfo {
  final Directory directory;
  final bool isInCorrectDirectory;

  ClassInfo({
    required this.directory,
    required this.isInCorrectDirectory,
  });
}
