import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web3auth_flutter/enums.dart';
import 'package:web3auth_flutter/input.dart';
import 'package:web3auth_flutter/output.dart';
import 'package:web3auth_flutter/web3auth_flutter.dart';
import 'package:web3dart/web3dart.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isInit = false;
  bool _isLoading = false;
  String? _privKey;
  String? _walletAddress;
  String? _userEmail;
  String? _userName;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _privKey != null && _privKey!.isNotEmpty;
  String? get walletAddress => _walletAddress;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get privKey => _privKey;

  // Provided by the user
  final String _clientId = "BP2iLctu45XXcp_HsTL8e_5UTKJk6ZfRI74Ll0v76LrR6HOz_B_iIqEKefACx5kvCBbhc0U17AD68QCUXkccYFc";

  Future<void> init() async {
    if (_isInit) return;

    try {
      Uri redirectUrl;
      if (Platform.isAndroid) {
        redirectUrl = Uri.parse('com.example.remitflow://auth');
      } else if (Platform.isIOS) {
        redirectUrl = Uri.parse('com.example.remitflow://auth');
      } else {
        redirectUrl = Uri.parse('http://localhost:8080');
      }

      await Web3AuthFlutter.init(Web3AuthOptions(
        clientId: _clientId,
        network: Network.sapphire_devnet, // Testnet network
        redirectUrl: redirectUrl,
        whiteLabel: WhiteLabelData(
          appName: "RemitFlow",
          mode: ThemeModes.dark,
        ),
      ));

      _isInit = true;
      await _checkSession();
    } catch (e) {
      debugPrint("Web3Auth init error: $e");
    }
  }

  Future<void> _checkSession() async {
    try {
      final String privKey = await Web3AuthFlutter.getPrivKey();
      if (privKey.isNotEmpty) {
        _privKey = privKey;
        _deriveWalletAddress();
        await _fetchUserDetails();
      }
    } catch (e) {
      debugPrint("No active session: $e");
    }
    notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    await _login(Provider.google);
  }

  Future<void> loginWithEmail(String email) async {
    await _login(Provider.email_passwordless, extraLoginOptions: ExtraLoginOptions(login_hint: email));
  }

  Future<void> _login(Provider provider, {ExtraLoginOptions? extraLoginOptions}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final Web3AuthResponse response = await Web3AuthFlutter.login(LoginParams(
        loginProvider: provider,
        mfaLevel: MFALevel.OPTIONAL,
        extraLoginOptions: extraLoginOptions,
      ));

      _privKey = response.privKey;
      if (_privKey != null) {
        _deriveWalletAddress();
      }
      await _fetchUserDetails();
    } catch (e) {
      debugPrint("Login error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchUserDetails() async {
    try {
      final userInfo = await Web3AuthFlutter.getUserInfo();
      _userEmail = userInfo.email;
      _userName = userInfo.name;
    } catch (e) {
      debugPrint("Error fetching user details: $e");
    }
  }

  // To be called after deriveAddress using web3dart
  void _deriveWalletAddress() {
    if (_privKey == null || _privKey!.isEmpty) return;
    try {
      final String hexKey = _privKey!.startsWith('0x') ? _privKey! : '0x$_privKey';
      final credentials = EthPrivateKey.fromHex(hexKey);
      _walletAddress = credentials.address.toString();
      debugPrint("Shardeum Wallet Address Derived: $_walletAddress");
    } catch (e) {
      debugPrint("Error deriving wallet address: $e");
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Web3AuthFlutter.logout();
      _privKey = null;
      _walletAddress = null;
      _userEmail = null;
      _userName = null;
    } catch (e) {
      debugPrint("Logout error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
