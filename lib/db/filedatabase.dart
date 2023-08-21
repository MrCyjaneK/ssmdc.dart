import 'dart:convert';
import 'dart:io';

import 'package:mutex/mutex.dart';
import 'package:path/path.dart' as p;

class FileDatabase {
  FileDatabase({
    required this.storePath,
  });

  final m = Mutex();
  final String storePath;
  late File file = File(p.join(storePath, "db.json"));

  Future<dynamic> get(String key) async {
    // await m.acquire();
    if (!file.existsSync()) {
      file = await file.create(recursive: true);
    }
    final string = file.readAsStringSync();
    // m.release();
    try {
      final map = json.decode(string);
      return map[key];
    } catch (e) {
      return null;
    }
  }

  Future<void> set(String key, dynamic value) async {
    // await m.acquire();
    if (!file.existsSync()) {
      file = await file.create(recursive: true);
    }

    final string = file.readAsStringSync();
    try {
      final map = json.decode(string);

      map[key] = value;
      file.writeAsStringSync(json.encode(map));
    } catch (e) {
      file.writeAsStringSync(json.encode({key: value}));
    }
    // m.release();
    return;
  }
}
