import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:web3dart/web3dart.dart';

class AuthService extends ChangeNotifier {
  AuthService._internal();

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  String? _privKey;
  String? _walletAddress;
  String? _userEmail;
  String? _userName;
  String? _userPhoto;
  String? _lastError;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _auth.currentUser != null;
  String? get walletAddress => _walletAddress;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get userPhoto => _userPhoto;
  String? get privKey => _privKey;
  String? get lastError => _lastError;
  String? get userPhoneNumber => _auth.currentUser?.phoneNumber;

  Future<void> init() async {
    try {
      if (_auth.currentUser != null) {
        await _restoreSession();
      }
    } catch (error) {
      debugPrint('AuthService init error: $error');
      _lastError = error.toString();
    }
  }

  Future<void> _restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    _userEmail = user.email;
    _userName = user.displayName;
    _userPhoto = user.photoURL;

    final storedKey = await _secureStorage.read(key: 'wallet_private_key');
    if (storedKey != null && storedKey.isNotEmpty) {
      _privKey = storedKey;
      _deriveWalletAddress();
    }
    notifyListeners();
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

      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user == null) {
        _lastError = 'Google sign-in did not return a Firebase user.';
        return false;
      }

      _userEmail = user.email;
      _userName = user.displayName;
      _userPhoto = user.photoURL;
      _privKey = _generatePrivateKey(user.uid);
      _deriveWalletAddress();

      await _secureStorage.write(key: 'wallet_private_key', value: _privKey);
      return true;
    } catch (error) {
      debugPrint('Login error: $error');
      _lastError = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getIdToken({bool forceRefresh = false}) {
    return _auth.currentUser?.getIdToken(forceRefresh);
  }

  String _generatePrivateKey(String uid) {
    final hmacKey = utf8.encode('remitflow-wallet-v1');
    final hmac = Hmac(sha256, hmacKey);
    final digest = hmac.convert(utf8.encode(uid));
    return digest.toString();
  }

  void _deriveWalletAddress() {
    if (_privKey == null || _privKey!.isEmpty) {
      return;
    }
    try {
      final hexKey = _privKey!.startsWith('0x') ? _privKey! : '0x$_privKey';
      final credentials = EthPrivateKey.fromHex(hexKey);
      _walletAddress = credentials.address.hexEip55;
    } catch (error) {
      debugPrint('Error deriving wallet address: $error');
      _lastError = 'Could not derive the wallet address from the saved key.';
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await _secureStorage.deleteAll();
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
