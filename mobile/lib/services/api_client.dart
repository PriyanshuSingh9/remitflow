import 'dart:convert';
import 'dart:io';

import 'backend_endpoint_resolver.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl}) : _baseUrlOverride = baseUrl;

  final String? _baseUrlOverride;

  Future<Map<String, dynamic>> getJson(
    String path, {
    required String sessionToken,
    Map<String, String>? queryParameters,
  }) {
    return _send(
      method: 'GET',
      path: path,
      sessionToken: sessionToken,
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required String sessionToken,
    Map<String, dynamic>? body,
  }) {
    return _send(
      method: 'POST',
      path: path,
      sessionToken: sessionToken,
      body: body,
    );
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    required String sessionToken,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final baseUrl = _baseUrlOverride ?? await BackendEndpointResolver.resolveBaseUrl();
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $sessionToken');
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
    } on BackendConnectionException catch (error) {
      throw ApiException(error.message);
    } on SocketException {
      throw const ApiException(
        'Could not reach the RemitFlow backend. Start the backend server and make sure port 8787 is reachable.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
