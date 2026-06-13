import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/session_log.dart';

class LogService {
  static Future<Directory> _logsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/logs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<File>> listLogs() async {
    final dir = await _logsDir();
    final files = await dir.list().where((e) => e.path.endsWith('.txt')).cast<File>().toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  static Future<File> saveLog(SessionLog log) async {
    final dir = await _logsDir();
    final name = '${_formatTimestamp(log.startTime)}.txt';
    final file = File('${dir.path}/$name');
    await file.writeAsString(log.toText());
    return file;
  }

  static String _formatTimestamp(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}'
      '${dt.month.toString().padLeft(2, '0')}'
      '${dt.day.toString().padLeft(2, '0')}_'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '${dt.second.toString().padLeft(2, '0')}';
}
