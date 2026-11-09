import 'package:flutter_test/flutter_test.dart';

import 'package:etiquetas_bling/main.dart';

void main() {
  testWidgets('App inicia na tela de busca de produtos', (WidgetTester tester) async {
    await tester.pumpWidget(const EtiquetasApp());
    await tester.pump();

    expect(find.text('Etiquetas Bling'), findsOneWidget);
    expect(find.text('Buscar produto por nome ou código'), findsOneWidget);
  });
}
