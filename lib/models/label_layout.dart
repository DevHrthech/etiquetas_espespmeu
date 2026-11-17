enum LabelFieldType { barcode, price, name, code }

extension LabelFieldTypeLabel on LabelFieldType {
  String get displayName => switch (this) {
        LabelFieldType.barcode => 'Código de barras',
        LabelFieldType.price => 'Preço',
        LabelFieldType.name => 'Nome do produto',
        LabelFieldType.code => 'Código interno',
      };

  String get sampleText => switch (this) {
        LabelFieldType.barcode => '',
        LabelFieldType.price => 'R\$ 29,90',
        LabelFieldType.name => 'Produto Exemplo',
        LabelFieldType.code => 'COD123',
      };
}

/// Um campo posicionável na etiqueta. Posição e tamanho em milímetros,
/// relativos ao canto superior esquerdo de uma única coluna da etiqueta.
class LabelElement {
  LabelFieldType type;
  double xMm;
  double yMm;

  /// Para o código de barras: altura das barras, em mm.
  /// Para campos de texto: altura aproximada da fonte, em mm.
  double sizeMm;

  LabelElement({
    required this.type,
    required this.xMm,
    required this.yMm,
    required this.sizeMm,
  });

  Map<String, Object?> toJson() => {
        'type': type.name,
        'x': xMm,
        'y': yMm,
        'size': sizeMm,
      };

  factory LabelElement.fromJson(Map<String, Object?> json) => LabelElement(
        type: LabelFieldType.values.byName(json['type'] as String),
        xMm: (json['x'] as num).toDouble(),
        yMm: (json['y'] as num).toDouble(),
        sizeMm: (json['size'] as num).toDouble(),
      );
}

class LabelLayout {
  final List<LabelElement> elements;
  LabelLayout(this.elements);

  /// Layout padrão: código de barras em cima, preço embaixo — igual ao
  /// que o app já imprimia antes de existir o editor.
  factory LabelLayout.standard() => LabelLayout([
        LabelElement(type: LabelFieldType.barcode, xMm: 1, yMm: 0.5, sizeMm: 5),
        LabelElement(type: LabelFieldType.price, xMm: 1, yMm: 7, sizeMm: 2.7),
      ]);

  Map<String, Object?> toJson() => {
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory LabelLayout.fromJson(Map<String, Object?> json) {
    final list = (json['elements'] as List)
        .cast<Map<String, Object?>>()
        .map(LabelElement.fromJson)
        .toList();
    return LabelLayout(list);
  }
}
