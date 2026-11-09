import 'package:flutter/material.dart';

import '../services/bling_auth_service.dart';
import '../services/printer_service.dart';
import '../services/secure_store.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _clientIdCtrl = TextEditingController();
  final _clientSecretCtrl = TextEditingController();

  List<String> _printers = [];
  String? _selectedPrinter;
  bool _loggedIn = false;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final creds = await SecureStore.instance.readCredentials();
    if (creds != null) {
      _clientIdCtrl.text = creds.$1;
      _clientSecretCtrl.text = creds.$2;
    }
    final loggedIn = await BlingAuthService.instance.isLoggedIn();
    final savedPrinter = await SecureStore.instance.printerName;
    List<String> printers = [];
    try {
      printers = PrinterService.instance.listPrinters();
    } catch (_) {
      // Em dev no macOS/Linux a API de impressão do Windows não existe.
    }
    setState(() {
      _loggedIn = loggedIn;
      _printers = printers;
      _selectedPrinter = savedPrinter;
    });
  }

  Future<void> _saveCredentials() async {
    setState(() => _busy = true);
    try {
      await BlingAuthService.instance.saveAppCredentials(
        _clientIdCtrl.text.trim(),
        _clientSecretCtrl.text.trim(),
      );
      setState(() => _status = 'Credenciais salvas.');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _status = 'Abrindo o navegador para login no Bling...';
    });
    try {
      await BlingAuthService.instance.login();
      setState(() {
        _loggedIn = true;
        _status = 'Login feito com sucesso.';
      });
    } catch (e) {
      setState(() => _status = 'Erro no login: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await BlingAuthService.instance.logout();
    setState(() {
      _loggedIn = false;
      _status = 'Sessão encerrada.';
    });
  }

  Future<void> _selectPrinter(String? name) async {
    setState(() => _selectedPrinter = name);
    if (name != null) {
      await SecureStore.instance.savePrinterName(name);
    }
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_status != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.creamCard,
                borderRadius: BorderRadius.circular(16),
                border: const Border(left: BorderSide(color: AppColors.wine, width: 4)),
              ),
              child: Text(_status!, style: const TextStyle(color: AppColors.wineDark)),
            ),
            const SizedBox(height: 20),
          ],
          _buildSectionCard(
            title: 'App do Bling',
            children: [
              Text(
                'Crie um app em bling.com.br > Configurações > Aplicativos, com '
                'Redirect URI: $blingRedirectUri',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _clientIdCtrl,
                decoration: const InputDecoration(labelText: 'Client ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientSecretCtrl,
                decoration: const InputDecoration(labelText: 'Client Secret'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _saveCredentials,
                child: const Text('Salvar credenciais'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: 'Login',
            children: [
              Row(
                children: [
                  Icon(
                    _loggedIn ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _loggedIn ? Colors.green : AppColors.wine,
                  ),
                  const SizedBox(width: 8),
                  Text(_loggedIn ? 'Conectado ao Bling' : 'Não conectado'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _login,
                    child: const Text('Entrar no Bling'),
                  ),
                  const SizedBox(width: 8),
                  if (_loggedIn)
                    OutlinedButton(
                      onPressed: _busy ? null : _logout,
                      child: const Text('Sair'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: 'Impressora',
            children: [
              if (_printers.isEmpty)
                const Text(
                  'Nenhuma impressora encontrada (ou rodando fora do Windows).',
                  style: TextStyle(color: AppColors.textMuted),
                )
              else
                DropdownButton<String>(
                  value: _selectedPrinter,
                  hint: const Text('Selecione a impressora'),
                  items: _printers
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: _selectPrinter,
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _load,
                child: const Text('Atualizar lista de impressoras'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
