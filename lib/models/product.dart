class Product {
  final int id;
  final String nome;
  final String codigo;
  final String? gtin;
  final double preco;

  Product({
    required this.id,
    required this.nome,
    required this.codigo,
    required this.gtin,
    required this.preco,
  });

  factory Product.fromBlingJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      nome: (json['nome'] ?? '') as String,
      codigo: (json['codigo'] ?? '') as String,
      gtin: json['gtin'] as String?,
      preco: _asDouble(json['preco']),
    );
  }

  factory Product.fromCacheRow(Map<String, Object?> row) {
    return Product(
      id: row['id'] as int,
      nome: row['nome'] as String,
      codigo: row['codigo'] as String,
      gtin: row['gtin'] as String?,
      preco: (row['preco'] as num).toDouble(),
    );
  }

  Map<String, Object?> toCacheRow() => {
        'id': id,
        'nome': nome,
        'codigo': codigo,
        'gtin': gtin,
        'preco': preco,
      };

  /// Código de barras usado na etiqueta (EAN-13 do GTIN; cai para o código
  /// interno se o produto não tiver GTIN cadastrado no Bling).
  String get barcodeValue => (gtin != null && gtin!.trim().isNotEmpty) ? gtin! : codigo;

  static double _asDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

/// Um item na fila de impressão: um produto + quantidade de etiquetas.
class PrintQueueItem {
  final Product product;
  int quantity;

  PrintQueueItem({required this.product, this.quantity = 1});
}
