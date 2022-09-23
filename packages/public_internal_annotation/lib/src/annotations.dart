import 'package:meta/meta_meta.dart';

const publicInternal = PublicInternal();

@Target({TargetKind.classType})
class PublicInternal {
  final int parentStep;
  final bool isStrict;

  const PublicInternal({
    this.parentStep = 0,
    this.isStrict = false,
  });
}
