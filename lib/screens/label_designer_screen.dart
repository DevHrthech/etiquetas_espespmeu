import 'package:flutter/material.dart';

import '../models/label_layout.dart';
import '../services/label_layout_store.dart';
import '../services/zpl_label_service.dart';
import '../theme.dart';

/// Editor visual da etiqueta: arraste os campos (código de barras, preço,
/// nome, código interno) dentro do retângulo que representa a etiqueta
/// física (39,8 × 10 mm) pra escolher onde cada um aparece impresso.
class LabelDesignerScreen extends StatefulWidget {
  const LabelDesignerScreen({super.key});

  @override
  State<LabelDesignerScreen> createState() => _LabelDesignerScreenState();
}

class _LabelDesignerScreenState extends State<LabelDesignerScreen> {
  static const double _scale = 14; // px por mm no editor (a etiqueta real é minúscula)
  static const double _widthMm = ZplLabelService.labelWidthMm;
  static const double _heightMm = ZplLabelService.labelHeightMm;

  LabelLayout? _layout;
  LabelFieldType? _selected;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final layout = await LabelLayoutStore.instance.load();
    setState(() => _layout = layout);
  }

  Future<void> _save() async {
    if (_layout == null) return;
    await LabelLayoutStore.instance.save(_layout!);
    setState(() => _status = 'Layout salvo.');
  }

  void _resetDefault() {
    setState(() {
      _layout = LabelLayout.standard();
      _status = 'Layout restaurado para o padrão.';
    });
  }

  void _addField(LabelFieldType type) {
    setState(() {
      _layout!.elements.add(LabelElement(
        type: type,
        xMm: 2,
        yMm: 2,
        sizeMm: type == LabelFieldType.barcode ? 5 : 2.5,
      ));
    });
  }

  void _removeField(LabelFieldType type) {
    setState(() {
      _layout!.elements.removeWhere((e) => e.type == type);
      if (_selected == type) _selected = null;
    });
  }

  void _moveElement(LabelElement el, Offset deltaPx) {
    setState(() {
      el.xMm = (el.xMm + deltaPx.dx / _scale).clamp(0, _widthMm - 2);
      el.yMm = (el.yMm + deltaPx.dy / _scale).clamp(0, _heightMm - 1.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor de etiqueta'),
        actions: [
          TextButton(onPressed: layout == null ? null : _resetDefault, child: const Text('Padrão')),
          const SizedBox(width: 8),
          FilledButton(onPressed: layout == null ? null : _save, child: const Text('Salvar')),
          const SizedBox(width: 16),
        ],
      ),
      body: layout == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_status != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.creamCard,
                        borderRadius: BorderRadius.circular(16),
                        border: const Border(left: BorderSide(color: AppColors.wine, width: 4)),
                      ),
                      child: Text(_status!, style: const TextStyle(color: AppColors.wineDark)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Arraste os campos dentro da etiqueta. Ela é física e bem pequena '
                    '(39,8 × 10 mm), então o espaço é apertado — use o controle de '
                    'tamanho pra fazer caber.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Center(child: _buildCanvas(layout)),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(width: 260, child: _buildFieldPanel(layout)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCanvas(LabelLayout layout) {
    return Container(
      width: _widthMm * _scale,
      height: _heightMm * _scale,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.wine, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: layout.elements.map((el) => _buildDraggableElement(el)).toList(),
      ),
    );
  }

  Widget _buildDraggableElement(LabelElement el) {
    final isSelected = _selected == el.type;
    final isBarcode = el.type == LabelFieldType.barcode;

    final child = isBarcode
        ? _BarcodeBars(width: 90, height: el.sizeMm * _scale)
        : Text(
            el.type.sampleText,
            style: TextStyle(fontSize: el.sizeMm * _scale * 0.62, color: AppColors.wineDark),
          );

    return Positioned(
      left: el.xMm * _scale,
      top: el.yMm * _scale,
      child: GestureDetector(
        onPanUpdate: (details) => _moveElement(el, details.delta),
        onTap: () => setState(() => _selected = el.type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isBarcode ? AppColors.creamCard : Colors.white.withValues(alpha: 0.9),
            border: Border.all(
              color: isSelected ? AppColors.wine : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFieldPanel(LabelLayout layout) {
    return ListView(
      children: [
        Text('Campos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final type in LabelFieldType.values) _buildFieldCard(layout, type),
      ],
    );
  }

  Widget _buildFieldCard(LabelLayout layout, LabelFieldType type) {
    final matches = layout.elements.where((e) => e.type == type).toList();
    final active = matches.isNotEmpty;
    final el = matches.isEmpty ? null : matches.first;
    final isBarcode = type == LabelFieldType.barcode;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(type.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: active,
                  onChanged: (v) => v ? _addField(type) : _removeField(type),
                ),
              ],
            ),
            if (active && el != null) ...[
              Text(
                isBarcode ? 'Altura das barras' : 'Tamanho da fonte',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              Slider(
                value: el.sizeMm,
                min: isBarcode ? 3 : 1.5,
                max: isBarcode ? 8 : 4,
                divisions: 20,
                label: '${el.sizeMm.toStringAsFixed(1)} mm',
                onChanged: (v) => setState(() => el.sizeMm = v),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Representação visual simplificada de um código de barras (barras
/// verticais de larguras variadas), só pra dar noção de espaço no editor.
class _BarcodeBars extends StatelessWidget {
  final double width;
  final double height;
  const _BarcodeBars({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _BarsPainter(),
    );
  }
}

class _BarsPainter extends CustomPainter {
  static const _pattern = [2, 1, 1, 2, 1, 3, 1, 1, 2, 1, 1, 2, 1, 3, 2, 1, 1, 1, 2, 1];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.wineDark;
    final totalUnits = _pattern.fold<int>(0, (sum, w) => sum + w);
    final unit = size.width / totalUnits;
    double x = 0;
    for (var i = 0; i < _pattern.length; i++) {
      final w = _pattern[i] * unit;
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
