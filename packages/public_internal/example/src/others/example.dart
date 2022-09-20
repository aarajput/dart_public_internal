import 'package:public_internal_annotation/public_internal_annotation.dart';

@publicInternal
class Example1 {}

@PublicInternal()
class Example2 {}

@PublicInternal(
  parentStep: 1,
)
class Example3 {}
