import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web3dart/web3dart.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  String? _privKey;
  String? _walletAddress;
  String? _userEmail;
  String? _userName;
  String? _userPhoto;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _auth.currentUser != null;
  String? get walletAddress => _walletAddress;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get userPhoto => _userPhoto;
  String? get privKey => _privKey;

  /// Initialize — check for existing Firebase auth session on app start
  Future<void> init() async {
    try {
      if (_auth.currentUser != null) {
        await _restoreSession();
      }
    } catch (e) {
      debugPrint("AuthService init error: $e");
    }
  }

  /// Restore saved session details from Firebase & secure storage
  Future<void> _restoreSession() async {
    final user = _auth.currentUser;
    if (user != null) {
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
  }

  /// Login with Google and link to Firebase Auth
  Future<void> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled the sign-in
        return;
      }

      final GoogleSignInAuthentication googleAuth = await account.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase using the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        _userEmail = user.email;
        _userName = user.displayName;
        _userPhoto = user.photoURL;

        // Generate a deterministic wallet from the Firebase UID (so it persists across authentications)
        _privKey = _generatePrivateKey(user.uid);
        _deriveWalletAddress();

        // Persist local key
        await _secureStorage.write(key: 'wallet_private_key', value: _privKey);

        // Store user and their wallet address in Firestore for admin analytics
        await _syncUserToFirestore(user, _walletAddress!);

        debugPrint("Login success — user: ${user.uid}, wallet: $_walletAddress");
      }
    } catch (e) {
      debugPrint("Login error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save the user to the "users" collection so admins can monitor sign-ups/wallets
  Future<void> _syncUserToFirestore(User user, String walletAuthAddress) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'name': user.displayName,
        'photoUrl': user.photoURL,
        'walletAddress': walletAuthAddress,
        'lastLogin': FieldValue.serverTimestamp(),
        'createdAt': user.metadata.creationTime?.toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error syncing user to Firestore: $e");
    }
  }

  /// Generate a deterministic 256-bit private key from a seed string.
  /// Uses HMAC-SHA256 with a domain-specific secret to ensure uniqueness.
  String _generatePrivateKey(String uid) {
    final hmacKey = utf8.encode('remitflow-wallet-v1');
    final hmac = Hmac(sha256, hmacKey);
    final digest = hmac.convert(utf8.encode(uid));
    return digest.toString(); // 64-char hex string = 256-bit key
  }

  /// Derive EVM wallet address from the stored private key
  void _deriveWalletAddress() {
    if (_privKey == null || _privKey!.isEmpty) return;
    try {
      final hexKey = _privKey!.startsWith('0x') ? _privKey! : '0x$_privKey';
      final credentials = EthPrivateKey.fromHex(hexKey);
      _walletAddress = credentials.address.toString();
      debugPrint("Wallet address: $_walletAddress");
    } catch (e) {
      debugPrint("Error deriving wallet address: $e");
    }
  }

  /// Logout — clear Google, Firebase session and local storage
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
    } catch (e) {
      debugPrint("Logout error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
