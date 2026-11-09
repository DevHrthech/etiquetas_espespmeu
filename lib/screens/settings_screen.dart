import 'package:flutter/material.dart';

import '../services/bling_auth_service.dart';
import '../services/printer_service.dart';
import '../services/secure_store.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Text('App do Bling', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Crie um app em bling.com.br > Configurações > Aplicativos, com '
              'Redirect URI: $blingRedirectUri',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clientIdCtrl,
              decoration: const InputDecoration(labelText: 'Client ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _clientSecretCtrl,
              decoration: const InputDecoration(labelText: 'Client Secret'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy ? null : _saveCredentials,
              child: const Text('Salvar credenciais'),
            ),
            const Divider(height: 32),
            Text('Login', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _loggedIn ? Icons.check_circle : Icons.cancel,
                  color: _loggedIn ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(_loggedIn ? 'Conectado ao Bling' : 'Não conectado'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
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
            const Divider(height: 32),
            Text('Impressora', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_printers.isEmpty)
              const Text('Nenhuma impressora encontrada (ou rodando fora do Windows).')
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
            ElevatedButton(
              onPressed: _load,
              child: const Text('Atualizar lista de impressoras'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!),
            ],
          ],
        ),
      ),
    );
  }
}
