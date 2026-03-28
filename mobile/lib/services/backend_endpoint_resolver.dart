import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendConnectionException implements Exception {
  const BackendConnectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendEndpointResolver {
  BackendEndpointResolver._();

  static String? _cachedBaseUrl;

  static Future<String> resolveBaseUrl({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedBaseUrl != null) {
      return _cachedBaseUrl!;
    }

    final configured = _configuredBaseUrl;
    if (configured != null) {
      final normalized = _normalize(configured);
      final reachable = await _isReachable(normalized);
      if (!reachable) {
        throw BackendConnectionException(
          'Could not reach the RemitFlow backend at $normalized. '
          'Update REMITFLOW_API_BASE_URL or start the backend server.',
        );
      }
      _cachedBaseUrl = normalized;
      return normalized;
    }

    for (final candidate in _defaultCandidates) {
      if (await _isReachable(candidate)) {
        _cachedBaseUrl = candidate;
        return candidate;
      }
    }

    throw BackendConnectionException(_defaultFailureMessage);
  }

  static void clearCache() {
    _cachedBaseUrl = null;
  }

  static String? get _configuredBaseUrl {
    const configured = String.fromEnvironment('REMITFLOW_API_BASE_URL');
    if (configured.isEmpty) {
      return null;
    }
    return configured;
  }

  static List<String> get _defaultCandidates {
    if (kIsWeb) {
      return const [
        'http://localhost:8787',
        'http://127.0.0.1:8787',
      ];
    }

    if (Platform.isAndroid) {
      return const [
        'http://127.0.0.1:8787',
        'http://10.0.2.2:8787',
        'http://localhost:8787',
      ];
    }

    return const [
      'http://127.0.0.1:8787',
      'http://localhost:8787',
    ];
  }

  static String get _defaultFailureMessage {
    if (Platform.isAndroid) {
      return 'Could not reach the RemitFlow backend. '
          'If you are using a physical Android device, run `adb reverse tcp:8787 tcp:8787` '
          'or launch the app with REMITFLOW_API_BASE_URL set to your computer\'s LAN IP. '
          'For the emulator, keep the backend running on port 8787.';
    }

    return 'Could not reach the RemitFlow backend. '
        'Start the backend on port 8787 or set REMITFLOW_API_BASE_URL.';
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  static Future<bool> _isReachable(String baseUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
