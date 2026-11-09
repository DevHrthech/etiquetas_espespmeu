import '../models/product.dart';

/// Gera ZPL para etiquetas de 39,8 x 10 mm, duas colunas por linha, com
/// 5 mm de espaço entre colunas, para impressão numa GK888t a 203 dpi.
///
/// A impressora só sente o gap entre linhas (sensor de etiqueta), então as
/// duas colunas de uma linha são enviadas juntas em um único ^XA...^XZ.
/// As dimensões aqui são um ponto de partida: ajuste fino (posições,
/// tamanho de fonte/barra) deve ser feito testando na impressora real.
class ZplLabelService {
  static const int dpmm = 8; // 203 dpi = 8 dots/mm
  static const double labelWidthMm = 39.8;
  static const double labelHeightMm = 10.0;
  static const double columnGapMm = 5.0;

  static final int _colWidthDots = (labelWidthMm * dpmm).round(); // 318
  static final int _gapDots = (columnGapMm * dpmm).round(); // 40
  static final int _rowHeightDots = (labelHeightMm * dpmm).round(); // 80
  static final int _rowWidthDots = _colWidthDots * 2 + _gapDots; // 676

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
    final barcode = _sanitizeBarcode(p.barcodeValue);
    final price = _formatPrice(p.preco);
    final zpl = StringBuffer();

    // Código de barras (EAN-13 se tiver 12-13 dígitos numéricos, senão Code128)
    final isEan13 = RegExp(r'^\d{12,13}$').hasMatch(barcode);
    final barHeight = 40; // 5 mm
    final barY = 4;
    if (isEan13) {
      final ean = barcode.padLeft(13, '0').substring(0, 13);
      zpl.writeln('^FO${offsetX + 8},$barY');
      zpl.writeln('^BY2,2,$barHeight');
      zpl.writeln('^BEN,$barHeight,Y,N');
      zpl.writeln('^FD$ean^FS');
    } else {
      zpl.writeln('^FO${offsetX + 8},$barY');
      zpl.writeln('^BY2,2,$barHeight');
      zpl.writeln('^BCN,$barHeight,N,N,N');
      zpl.writeln('^FD$barcode^FS');
    }

    // Preço, abaixo do código de barras (com o texto do EAN já incluso
    // pelo ^BEN acima; para Code128 o texto legível já vem do ^BCN).
    zpl.writeln('^FO${offsetX + 8},${_rowHeightDots - 24}');
    zpl.writeln('^A0N,22,22');
    zpl.writeln('^FDR\$ $price^FS');

    return zpl.toString();
  }

  String _sanitizeBarcode(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), '');

  String _formatPrice(double value) {
    final rounded = (value * 100).round() / 100;
    final parts = rounded.toStringAsFixed(2).split('.');
    return '${parts[0]},${parts[1]}';
  }
}
