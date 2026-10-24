import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient(this._client, {this.timeout = const Duration(seconds: 20)});

  static final baseUri = Uri.parse('https://mobilab-task-api.vercel.app');
  final http.Client _client;
  final Duration timeout;

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = baseUri.resolve(path);
    final target = queryParameters == null || queryParameters.isEmpty
        ? uri
        : uri.replace(queryParameters: queryParameters);
    try {
      final response = await _client
          .get(target, headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          response.statusCode == 404
              ? 'Etkinlik bulunamadı.'
              : response.statusCode >= 500
              ? 'Sunucu şu anda yanıt veremiyor. Lütfen tekrar deneyin.'
              : 'Etkinlikler alınamadı. Lütfen tekrar deneyin.',
          statusCode: response.statusCode,
        );
      }
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('JSON nesnesi bekleniyordu.');
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException(
        'İstek zaman aşımına uğradı. Lütfen tekrar deneyin.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Bağlantı kurulamadı. İnternet bağlantınızı kontrol edin.',
      );
    } on FormatException {
      throw const ApiException(
        'Sunucudan gelen yanıt okunamadı. Lütfen tekrar deneyin.',
      );
    }
  }
}
