import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';
import 'bling_auth_service.dart';

/// Busca produtos na API v3 do Bling. A API limita a ~3 requisições por
/// segundo, então aqui espaçamos as chamadas de paginação.
class BlingApiService {
  BlingApiService._();
  static final BlingApiService instance = BlingApiService._();

  static const _baseUrl = 'https://www.bling.com.br/Api/v3';
  static const _pageDelay = Duration(milliseconds: 400);

  /// Baixa todos os produtos ativos, página por página.
  Future<List<Product>> fetchAllProducts({void Function(int fetched)? onProgress}) async {
    final products = <Product>[];
    var page = 1;
    while (true) {
      final pageItems = await _fetchPage(page);
      if (pageItems.isEmpty) break;
      products.addAll(pageItems);
      onProgress?.call(products.length);
      page++;
      await Future.delayed(_pageDelay);
    }
    return products;
  }

  Future<List<Product>> _fetchPage(int page) async {
    final token = await BlingAuthService.instance.getValidAccessToken();
    final uri = Uri.parse('$_baseUrl/produtos').replace(queryParameters: {
      'pagina': '$page',
      'limite': '100',
      'situacao': 'A',
    });

    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar produtos no Bling (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (json['data'] as List?) ?? const [];
    return data
        .cast<Map<String, dynamic>>()
        .map(Product.fromBlingJson)
        .toList();
  }
}
