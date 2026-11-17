import '../models/label_layout.dart';
import '../models/product.dart';

/// Gera ZPL para etiquetas de 39,8 x 10 mm, duas colunas por linha, com
/// 5 mm de espaço entre colunas, para impressão numa GK888t a 203 dpi.
///
/// A impressora só sente o gap entre linhas (sensor de etiqueta), então as
/// duas colunas de uma linha são enviadas juntas em um único ^XA...^XZ.
/// A posição de cada campo (código de barras, preço, nome, código) vem do
/// [LabelLayout], editável na tela de design da etiqueta.
class ZplLabelService {
  static const int dpmm = 8; // 203 dpi = 8 dots/mm
  static const double labelWidthMm = 39.8;
  static const double labelHeightMm = 10.0;
  static const double columnGapMm = 5.0;

  static final int _colWidthDots = (labelWidthMm * dpmm).round(); // 318
  static final int _gapDots = (columnGapMm * dpmm).round(); // 40
  static final int _rowHeightDots = (labelHeightMm * dpmm).round(); // 80
  static final int _rowWidthDots = _colWidthDots * 2 + _gapDots; // 676

  final LabelLayout layout;

  ZplLabelService(this.layout);

  /// Monta o ZPL completo para a fila de impressão, agrupando os itens em
  /// pares (coluna esquerda / direita). Se o total de etiquetas for ímpar,
  /// a última coluna direita fica em branco.
  String buildZplForQueue(List<PrintQueueItem> queue) {
    final flat = <Product>[];
    for (final item in queue) {
      for (var i = 0; i < item.quantity; i++) {
        flat.add(item.product);
      }
    }

    final buffer = StringBuffer();
    for (var i = 0; i < flat.length; i += 2) {
      final left = flat[i];
      final right = (i + 1 < flat.length) ? flat[i + 1] : null;
      buffer.write(_buildRow(left, right));
    }
    return buffer.toString();
  }

  String _buildRow(Product left, Product? right) {
    final zpl = StringBuffer();
    zpl.writeln('^XA');
    zpl.writeln('^PW$_rowWidthDots');
    zpl.writeln('^LL$_rowHeightDots');
    zpl.writeln('^LH0,0');

    zpl.write(_buildColumn(left, offsetX: 0));
    if (right != null) {
      zpl.write(_buildColumn(right, offsetX: _colWidthDots + _gapDots));
    }

    zpl.writeln('^XZ');
    return zpl.toString();
  }

  String _buildColumn(Product p, {required int offsetX}) {
    final zpl = StringBuffer();
    for (final el in layout.elements) {
      final x = offsetX + (el.xMm * dpmm).round();
      final y = (el.yMm * dpmm).round();
      switch (el.type) {
        case LabelFieldType.barcode:
          zpl.write(_buildBarcode(p, x: x, y: y, heightDots: (el.sizeMm * dpmm).round()));
        case LabelFieldType.price:
          zpl.write(_buildText('R\$ ${_formatPrice(p.preco)}', x: x, y: y, fontDots: (el.sizeMm * dpmm).round()));
        case LabelFieldType.name:
          zpl.write(_buildText(p.nome, x: x, y: y, fontDots: (el.sizeMm * dpmm).round()));
        case LabelFieldType.code:
          zpl.write(_buildText(p.codigo, x: x, y: y, fontDots: (el.sizeMm * dpmm).round()));
      }
    }
    return zpl.toString();
  }

  String _buildBarcode(Product p, {required int x, required int y, required int heightDots}) {
    final barcode = _sanitizeBarcode(p.barcodeValue);
    final isEan13 = RegExp(r'^\d{12,13}$').hasMatch(barcode);
    final zpl = StringBuffer();
    if (isEan13) {
      final ean = barcode.padLeft(13, '0').substring(0, 13);
      zpl.writeln('^FO$x,$y');
      zpl.writeln('^BY2,2,$heightDots');
      zpl.writeln('^BEN,$heightDots,Y,N');
      zpl.writeln('^FD$ean^FS');
    } else {
      zpl.writeln('^FO$x,$y');
      zpl.writeln('^BY2,2,$heightDots');
      zpl.writeln('^BCN,$heightDots,N,N,N');
      zpl.writeln('^FD$barcode^FS');
    }
    return zpl.toString();
  }

  String _buildText(String text, {required int x, required int y, required int fontDots}) {
    final zpl = StringBuffer();
    zpl.writeln('^FO$x,$y');
    zpl.writeln('^A0N,$fontDots,$fontDots');
    zpl.writeln('^FD${_escapeZplText(text)}^FS');
    return zpl.toString();
  }

  String _sanitizeBarcode(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), '');

  String _escapeZplText(String raw) => raw.replaceAll('^', '').replaceAll('~', '');

  String _formatPrice(double value) {
    final rounded = (value * 100).round() / 100;
    final parts = rounded.toStringAsFixed(2).split('.');
    return '${parts[0]},${parts[1]}';
  }
}
