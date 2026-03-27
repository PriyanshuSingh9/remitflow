import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl}) : _baseUrl = baseUrl ?? _resolveBaseUrl();

  final String _baseUrl;

  static String _resolveBaseUrl() {
    const configured = String.fromEnvironment('REMITFLOW_API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured;
    }
    if (kIsWeb) {
      return 'http://localhost:8787';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8787';
    }
    return 'http://127.0.0.1:8787';
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    required String idToken,
    Map<String, String>? queryParameters,
  }) {
    return _send(
      method: 'GET',
      path: path,
      idToken: idToken,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required String idToken,
    Map<String, dynamic>? body,
  }) {
    return _send(
      method: 'POST',
      path: path,
      idToken: idToken,
      body: body,
    );
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    required String idToken,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.headers.contentType = ContentType.json;
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final payload = await response.transform(utf8.decoder).join();
      final decoded = payload.isEmpty ? <String, dynamic>{} : jsonDecode(payload);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map<String, dynamic> && decoded['error'] is String
            ? decoded['error'] as String
            : 'Request failed with status ${response.statusCode}';
        throw ApiException(message, statusCode: response.statusCode);
      }

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw const ApiException('Unexpected response from backend.');
    } on SocketException {
      throw const ApiException(
        'Could not reach the RemitFlow backend. Start the local server or set REMITFLOW_API_BASE_URL.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
