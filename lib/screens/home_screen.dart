import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../services/bling_api_service.dart';
import '../services/bling_auth_service.dart';
import '../services/printer_service.dart';
import '../services/product_cache.dart';
import '../services/secure_store.dart';
import '../services/zpl_label_service.dart';
import '../theme.dart';
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
          if (_status != null) _buildStatusBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar produto por nome ou código',
                prefixIcon: const Icon(Icons.search_rounded),
                helperText: _lastSync == null
                    ? 'Produtos ainda não sincronizados'
                    : 'Última sincronização: ${DateFormat('dd/MM HH:mm').format(_lastSync!)}',
              ),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildResultsList()),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _buildQueuePanel()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.creamCard,
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: AppColors.wine, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_status!, style: const TextStyle(color: AppColors.wineDark))),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _status = null),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_results.isEmpty) {
      return const Center(
        child: Text('Nenhum produto encontrado.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = _results[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _addToQueue(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          'Código: ${p.codigo}${p.gtin != null ? ' · GTIN: ${p.gtin}' : ''}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _currency.format(p.preco),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.wine),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.add_circle_rounded, color: AppColors.wine),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQueuePanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Fila de impressão',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.blush.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$_totalLabels etiqueta(s)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.wineDark),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _queue.isEmpty
                ? const Center(
                    child: Text(
                      'Toque em um produto para adicionar.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _queue.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _queue[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.creamSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.nome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                  ),
                                  Text(
                                    _currency.format(item.product.preco),
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            _buildQuantityStepper(item),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              onPressed: () => _removeFromQueue(item),
                            ),
                          ],
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
                icon: const Icon(Icons.print_rounded),
                label: const Text('Imprimir etiquetas'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityStepper(PrintQueueItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded),
            onPressed: () => _updateQuantity(item, item.quantity - 1),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _updateQuantity(item, item.quantity + 1),
          ),
        ],
      ),
    );
  }
}
