import 'package:public_internal_annotation/public_internal_annotation.dart';

@publicInternal
class Example1 {}

@PublicInternal()
class Example2 {}

@PublicInternal(
  parentStep: 1,
)
class Example3 {}

@PublicInternal(
  isStrict: true,
)
class Example4 {}

@PublicInternal(
  parentStep: 1,
  isStrict: true,
)
class Example5 {
  final a = 'hello class';

  const Example5();

  // void public() {
  //   final b = 'world';
  // }
}
