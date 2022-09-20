import 'package:meta/meta_meta.dart';

const publicInternal = PublicInternal();

@Target({TargetKind.classType})
class PublicInternal {
  final int parentStep;

  const PublicInternal({
    final parentStep = 0,
  });
}
