import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/product.dart';

/// Cache local dos produtos do Bling, para a busca no app ser instantânea
/// mesmo com os limites de requisição da API.
class ProductCache {
  ProductCache._();
  static final ProductCache instance = ProductCache._();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    await Directory(dir.path).create(recursive: true);
    final db = sqlite3.open('${dir.path}/produtos_cache.db');
    db.execute('''
      CREATE TABLE IF NOT EXISTS produtos (
        id INTEGER PRIMARY KEY,
        nome TEXT NOT NULL,
        codigo TEXT NOT NULL,
        gtin TEXT,
        preco REAL NOT NULL
      );
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_produtos_nome ON produtos(nome);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_produtos_codigo ON produtos(codigo);
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS meta (
        chave TEXT PRIMARY KEY,
        valor TEXT
      );
    ''');
    _db = db;
    return db;
  }

  Future<void> replaceAll(List<Product> products) async {
    final db = await _open();
    db.execute('BEGIN TRANSACTION;');
    try {
      db.execute('DELETE FROM produtos;');
      final stmt = db.prepare(
        'INSERT INTO produtos (id, nome, codigo, gtin, preco) VALUES (?, ?, ?, ?, ?);',
      );
      for (final p in products) {
        stmt.execute([p.id, p.nome, p.codigo, p.gtin, p.preco]);
      }
      stmt.dispose();
      db.execute(
        "INSERT OR REPLACE INTO meta (chave, valor) VALUES ('last_sync', '${DateTime.now().toIso8601String()}');",
      );
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  Future<DateTime?> lastSync() async {
    final db = await _open();
    final result = db.select("SELECT valor FROM meta WHERE chave = 'last_sync';");
    if (result.isEmpty) return null;
    return DateTime.tryParse(result.first['valor'] as String);
  }

  Future<List<Product>> search(String query, {int limit = 50}) async {
    final db = await _open();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      final rows = db.select('SELECT * FROM produtos ORDER BY nome LIMIT ?;', [limit]);
      return rows.map(Product.fromCacheRow).toList();
    }
    final like = '%$trimmed%';
    final rows = db.select(
      'SELECT * FROM produtos WHERE nome LIKE ? OR codigo LIKE ? OR gtin LIKE ? ORDER BY nome LIMIT ?;',
      [like, like, like, limit],
    );
    return rows.map(Product.fromCacheRow).toList();
  }

  Future<int> count() async {
    final db = await _open();
    final rows = db.select('SELECT COUNT(*) as c FROM produtos;');
    return rows.first['c'] as int;
  }
}
