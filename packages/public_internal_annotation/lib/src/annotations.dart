import 'package:meta/meta_meta.dart';

const publicInternal = PublicInternal();

@Target({TargetKind.classType})
class PublicInternal {
  const PublicInternal();
}
