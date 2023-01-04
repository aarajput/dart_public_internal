import 'package:public_internal_annotation/public_internal_annotation.dart';

@publicInternal
class Example1 {}

@PublicInternal(
  parentStep: 1,
  isStrict: true,
)
class Example2 {}
