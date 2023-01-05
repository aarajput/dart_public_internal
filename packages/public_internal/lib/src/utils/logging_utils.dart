import 'package:ansicolor/ansicolor.dart';
import 'package:logging/logging.dart';

class LoggingUtils {
  static const _ignore = [];

  static void initialize() {
    ansiColorDisabled = false;
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((final record) {
      AnsiPen? pen;
      if (record.level == Level.SEVERE) {
        pen = AnsiPen()..red();
      } else if (record.level == Level.WARNING) {
        pen = AnsiPen()..yellow();
      } else if (record.level == Level.INFO) {
        pen = AnsiPen()..blue();
      } else if (record.level == Level.FINE) {
        pen = AnsiPen()..cyan();
      } else if (record.level == Level.FINER) {
        pen = AnsiPen()..green();
      } else if (record.level == Level.CONFIG) {
        pen = AnsiPen()..rgb(r: 0.5, g: 0.5, b: 0.5);
      } else if (record.level == Level.OFF) {
        pen = null;
      } else {
        pen = AnsiPen()..gray();
      }
      if (pen != null && _ignore.contains(record.loggerName)) {
        pen = null;
      }
      if (pen != null) {
        // ignore: avoid_print
        print(pen('${record.loggerName}: ${record.message}'));
      }
    });
  }
}
