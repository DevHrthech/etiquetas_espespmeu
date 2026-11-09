import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const EtiquetasApp());
}

class EtiquetasApp extends StatelessWidget {
  const EtiquetasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Etiquetas Bling',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
