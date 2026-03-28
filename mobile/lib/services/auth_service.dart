import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

import 'backend_endpoint_resolver.dart';

class AuthService extends ChangeNotifier {
  AuthService._internal();

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  static const String _defaultGoogleServerClientId =
      '612184936512-j4tl40a3lmd793k0cirue0t2lca8660k.apps.googleusercontent.com';
  static const String _sessionTokenKey = 'session_token';
  static const String _walletKey = 'wallet_private_key';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _userPhotoKey = 'user_photo';

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _googleServerClientId,
  );
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  String? _privKey;
  String? _walletAddress;
  String? _userEmail;
  String? _userName;
  String? _userPhoto;
  String? _sessionToken;
  String? _lastError;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _sessionToken != null && _sessionToken!.isNotEmpty;
  String? get walletAddress => _walletAddress;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get userPhoto => _userPhoto;
  String? get privKey => _privKey;
  String? get lastError => _lastError;
  String? get userPhoneNumber => null;
  String? get sessionToken => _sessionToken;

  String get _googleServerClientId {
    const configured = String.fromEnvironment('REMITFLOW_GOOGLE_SERVER_CLIENT_ID');
    if (configured.isNotEmpty) {
      return configured;
    }
    return _defaultGoogleServerClientId;
  }

  Future<void> init() async {
    try {
      _sessionToken = await _secureStorage.read(key: _sessionTokenKey);
      _userEmail = await _secureStorage.read(key: _userEmailKey);
      _userName = await _secureStorage.read(key: _userNameKey);
      _userPhoto = await _secureStorage.read(key: _userPhotoKey);

      final storedKey = await _secureStorage.read(key: _walletKey);
      if (storedKey != null && storedKey.isNotEmpty) {
        _privKey = storedKey;
        _deriveWalletAddress();
      }
      notifyListeners();
    } catch (error) {
      debugPrint('AuthService init error: $error');
      _lastError = error.toString();
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        _lastError = 'Google sign-in was cancelled.';
        return false;
      }

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        _lastError =
            'Google sign-in completed, but no ID token was returned. Check the Google web client ID.';
        return false;
      }

      _userEmail = account.email;
      _userName = account.displayName;
      _userPhoto = account.photoUrl;

      final googleSubject = _extractGoogleSubject(idToken) ?? account.id;
      _privKey = _generatePrivateKey(googleSubject);
      _deriveWalletAddress();
      await _secureStorage.write(key: _walletKey, value: _privKey);
      final backendBaseUrl = await BackendEndpointResolver.resolveBaseUrl(
        forceRefresh: true,
      );

      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idToken': idToken,
              'walletAddress': _walletAddress,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final details = payload['error'] ?? payload['details'] ?? 'Authentication failed.';
        _lastError = details.toString();
        return false;
      }

      final user = payload['user'] as Map<String, dynamic>;
      _sessionToken = payload['token'] as String?;
      _userEmail = (user['email'] as String?) ?? _userEmail;
      _userName = (user['displayName'] as String?) ?? _userName;
      _userPhoto = (user['photoUrl'] as String?) ?? _userPhoto;
      _walletAddress = (user['walletAddress'] as String?) ?? _walletAddress;

      await _secureStorage.write(key: _sessionTokenKey, value: _sessionToken);
      await _secureStorage.write(key: _userEmailKey, value: _userEmail);
      await _secureStorage.write(key: _userNameKey, value: _userName);
      await _secureStorage.write(key: _userPhotoKey, value: _userPhoto);
      return true;
    } on BackendConnectionException catch (error) {
      _lastError = error.message;
      return false;
    } on SocketException {
      _lastError =
          'Could not reach the RemitFlow backend. Start the backend server and make sure port 8787 is reachable.';
      return false;
    } on http.ClientException catch (error) {
      _lastError = error.message;
      return false;
    } catch (error) {
      debugPrint('Login error: $error');
      _lastError = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _generatePrivateKey(String subject) {
    final hmacKey = utf8.encode('remitflow-wallet-v1');
    final hmac = Hmac(sha256, hmacKey);
    final digest = hmac.convert(utf8.encode(subject));
    return digest.toString();
  }

  String? _extractGoogleSubject(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) {
        return null;
      }

      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final sub = payload['sub'];
      return sub is String && sub.isNotEmpty ? sub : null;
    } catch (_) {
      return null;
    }
  }

  void _deriveWalletAddress() {
    if (_privKey == null || _privKey!.isEmpty) {
      return;
    }
    try {
      final hexKey = _privKey!.startsWith('0x') ? _privKey! : '0x$_privKey';
      final credentials = EthPrivateKey.fromHex(hexKey);
      _walletAddress = credentials.address.eip55With0x;
    } catch (error) {
      debugPrint('Error deriving wallet address: $error');
      _lastError = 'Could not derive the wallet address from the saved key.';
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _googleSignIn.signOut();
      await _secureStorage.deleteAll();
      _sessionToken = null;
      _privKey = null;
      _walletAddress = null;
      _userEmail = null;
      _userName = null;
      _userPhoto = null;
      _lastError = null;
    } catch (error) {
      debugPrint('Logout error: $error');
      _lastError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
