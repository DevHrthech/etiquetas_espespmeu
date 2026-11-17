import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/label_layout.dart';

/// Guarda o layout da etiqueta (quais campos aparecem e onde) escolhido
/// no editor, pra persistir entre sessões do app.
class LabelLayoutStore {
  LabelLayoutStore._();
  static final LabelLayoutStore instance = LabelLayoutStore._();

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await Directory(dir.path).create(recursive: true);
    return File('${dir.path}/label_layout.json');
  }

  Future<LabelLayout> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return LabelLayout.standard();
      final content = await file.readAsString();
      return LabelLayout.fromJson(jsonDecode(content) as Map<String, Object?>);
    } catch (_) {
      return LabelLayout.standard();
    }
  }

  Future<void> save(LabelLayout layout) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(layout.toJson()));
  }
}
