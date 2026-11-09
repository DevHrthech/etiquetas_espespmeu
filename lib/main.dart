import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const EtiquetasApp());
}

class EtiquetasApp extends StatelessWidget {
  const EtiquetasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Etiquetas Bling',
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
