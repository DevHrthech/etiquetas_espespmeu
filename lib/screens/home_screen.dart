import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../services/bling_api_service.dart';
import '../services/bling_auth_service.dart';
import '../services/printer_service.dart';
import '../services/product_cache.dart';
import '../services/secure_store.dart';
import '../services/zpl_label_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  List<Product> _results = [];
  final List<PrintQueueItem> _queue = [];

  bool _syncing = false;
  int _syncCount = 0;
  DateTime? _lastSync;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final lastSync = await ProductCache.instance.lastSync();
    final count = await ProductCache.instance.count();
    setState(() => _lastSync = lastSync);
    if (count == 0) {
      await _syncProducts();
    } else {
      await _search('');
    }
  }

  Future<void> _syncProducts() async {
    final loggedIn = await BlingAuthService.instance.isLoggedIn();
    if (!loggedIn) {
      setState(() => _status = 'Faça login no Bling nas Configurações antes de sincronizar.');
      return;
    }
    setState(() {
      _syncing = true;
      _syncCount = 0;
      _status = 'Sincronizando produtos do Bling...';
    });
    try {
      final products = await BlingApiService.instance.fetchAllProducts(
        onProgress: (n) => setState(() {
          _syncCount = n;
          _status = 'Sincronizando produtos do Bling... ($_syncCount)';
        }),
      );
      await ProductCache.instance.replaceAll(products);
      setState(() {
        _status = '${products.length} produtos sincronizados.';
        _lastSync = DateTime.now();
      });
      await _search(_searchCtrl.text);
    } catch (e) {
      setState(() => _status = 'Erro ao sincronizar: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _search(String query) async {
    final results = await ProductCache.instance.search(query);
    setState(() => _results = results);
  }

  void _addToQueue(Product product) {
    setState(() {
      final matches = _queue.where((i) => i.product.id == product.id);
      if (matches.isNotEmpty) {
        matches.first.quantity++;
      } else {
        _queue.add(PrintQueueItem(product: product, quantity: 1));
      }
    });
  }

  void _updateQuantity(PrintQueueItem item, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _queue.remove(item);
      } else {
        item.quantity = quantity;
      }
    });
  }

  void _removeFromQueue(PrintQueueItem item) {
    setState(() => _queue.remove(item));
  }

  int get _totalLabels => _queue.fold(0, (sum, i) => sum + i.quantity);

  Future<void> _printQueue() async {
    if (_queue.isEmpty) return;
    final printerName = await SecureStore.instance.printerName;
    if (printerName == null) {
      setState(() => _status = 'Selecione uma impressora nas Configurações.');
      return;
    }
    try {
      final zpl = ZplLabelService().buildZplForQueue(_queue);
      PrinterService.instance.printRaw(printerName, zpl);
      setState(() {
        _status = '$_totalLabels etiqueta(s) enviada(s) para "$printerName".';
        _queue.clear();
      });
    } catch (e) {
      setState(() => _status = 'Erro ao imprimir: $e');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etiquetas Bling'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar produtos',
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _syncing ? null : _syncProducts,
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_status != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_status!),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Buscar produto por nome ou código',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                helperText: _lastSync == null
                    ? 'Produtos ainda não sincronizados'
                    : 'Última sincronização: ${DateFormat('dd/MM HH:mm').format(_lastSync!)}',
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildResultsList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: _buildQueuePanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_results.isEmpty) {
      return const Center(child: Text('Nenhum produto encontrado.'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final p = _results[index];
        return ListTile(
          title: Text(p.nome),
          subtitle: Text('Código: ${p.codigo}${p.gtin != null ? ' · GTIN: ${p.gtin}' : ''}'),
          trailing: Text(_currency.format(p.preco)),
          onTap: () => _addToQueue(p),
        );
      },
    );
  }

  Widget _buildQueuePanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Fila de impressão',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$_totalLabels etiqueta(s)'),
            ],
          ),
        ),
        Expanded(
          child: _queue.isEmpty
              ? const Center(child: Text('Toque em um produto para adicionar.'))
              : ListView.builder(
                  itemCount: _queue.length,
                  itemBuilder: (context, index) {
                    final item = _queue[index];
                    return ListTile(
                      title: Text(item.product.nome),
                      subtitle: Text(_currency.format(item.product.preco)),
                      trailing: SizedBox(
                        width: 160,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () => _updateQuantity(item, item.quantity - 1),
                            ),
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${item.quantity}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _updateQuantity(item, item.quantity + 1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeFromQueue(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _queue.isEmpty ? null : _printQueue,
              icon: const Icon(Icons.print),
              label: const Text('Imprimir etiquetas'),
            ),
          ),
        ),
      ],
    );
  }
}
