import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import 'app_repository.dart';
import 'auth_service.dart';

class AppDataService extends ChangeNotifier {
  AppDataService._internal();

  static final AppDataService _instance = AppDataService._internal();

  factory AppDataService() => _instance;

  final AppRepository _repository = AppRepository();

  SessionUser? _sessionUser;
  DashboardData? _dashboard;
  ReceiverDashboardData? _receiverDashboard;
  List<RecipientSummary> _recipients = const [];
  bool _isBootstrapping = false;
  bool _isDashboardLoading = false;
  bool _isRecipientsLoading = false;
  bool _isTransferSubmitting = false;
  int _recipientSearchSequence = 0;
  String? _bootstrapErrorMessage;
  String? _recipientsErrorMessage;
  String? _transferErrorMessage;

  SessionUser? get sessionUser => _sessionUser;
  DashboardData? get dashboard => _dashboard;
  ReceiverDashboardData? get receiverDashboard => _receiverDashboard;
  List<RecipientSummary> get recipients => _recipients;
  bool get isBootstrapping => _isBootstrapping;
  bool get isDashboardLoading => _isDashboardLoading;
  bool get isRecipientsLoading => _isRecipientsLoading;
  bool get isTransferSubmitting => _isTransferSubmitting;
  String? get bootstrapErrorMessage => _bootstrapErrorMessage;
  String? get recipientsErrorMessage => _recipientsErrorMessage;
  String? get transferErrorMessage => _transferErrorMessage;
  bool get hasSession =>
      _sessionUser != null || _dashboard != null || _recipients.isNotEmpty;

  Future<void> bootstrapAuthenticatedUser({bool forceRefresh = false}) async {
    if (!AuthService().isAuthenticated) {
      clear();
      return;
    }
    if (_isBootstrapping) {
      return;
    }
    if (_dashboard != null && _sessionUser != null && !forceRefresh) {
      return;
    }

    _isBootstrapping = true;
    _bootstrapErrorMessage = null;
    notifyListeners();

    try {
      final sessionToken = _requireSessionToken();
      _sessionUser = await _repository.fetchCurrentUser(
        sessionToken: sessionToken,
      );
      _dashboard = await _repository.fetchDashboard(sessionToken: sessionToken);
      _sessionUser = _dashboard!.user;
    } catch (error) {
      _bootstrapErrorMessage = _readableError(error);
      if (forceRefresh) {
        _dashboard = null;
      }
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> refreshDashboard() async {
    if (!AuthService().isAuthenticated || _isDashboardLoading) {
      return;
    }

    _isDashboardLoading = true;
    _bootstrapErrorMessage = null;
    notifyListeners();

    try {
      final sessionToken = _requireSessionToken();
      _dashboard = await _repository.fetchDashboard(sessionToken: sessionToken);
      _sessionUser = _dashboard!.user;
    } catch (error) {
      _bootstrapErrorMessage = _readableError(error);
    } finally {
      _isDashboardLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshReceiverDashboard() async {
    if (!AuthService().isAuthenticated) {
      return;
    }

    try {
      final sessionToken = _requireSessionToken();
      _receiverDashboard = await _repository.fetchReceiverDashboard(
        sessionToken: sessionToken,
      );
      _sessionUser = _receiverDashboard!.user;
      notifyListeners();
    } catch (error) {
      _bootstrapErrorMessage = _readableError(error);
      notifyListeners();
    }
  }

  Future<void> searchRecipients(String query) async {
    if (!AuthService().isAuthenticated) {
      return;
    }

    final requestId = ++_recipientSearchSequence;
    _isRecipientsLoading = true;
    _recipientsErrorMessage = null;
    notifyListeners();

    try {
      final sessionToken = _requireSessionToken();
      final results = await _repository.searchRecipients(
        sessionToken: sessionToken,
        query: query.trim(),
      );
      if (requestId == _recipientSearchSequence) {
        _recipients = results;
      }
    } catch (error) {
      if (requestId == _recipientSearchSequence) {
        _recipientsErrorMessage = _readableError(error);
        _recipients = const [];
      }
    } finally {
      if (requestId == _recipientSearchSequence) {
        _isRecipientsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<TransferReceipt> submitTransfer({
    required String recipientId,
    required double amountUsd,
  }) async {
    if (_isTransferSubmitting) {
      throw StateError('A transfer is already in progress.');
    }

    _isTransferSubmitting = true;
    _transferErrorMessage = null;
    notifyListeners();

    try {
      final sessionToken = _requireSessionToken();
      final receipt = await _repository.createTransfer(
        sessionToken: sessionToken,
        recipientId: recipientId,
        amountUsd: amountUsd,
      );
      await refreshDashboard();
      return receipt;
    } catch (error) {
      _transferErrorMessage = _readableError(error);
      rethrow;
    } finally {
      _isTransferSubmitting = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getTransferStatus(String transactionId) async {
    if (!AuthService().isAuthenticated) {
      return null;
    }
    try {
      final sessionToken = _requireSessionToken();
      return await _repository.getTransferStatus(
        sessionToken: sessionToken,
        transactionId: transactionId,
      );
    } catch (error) {
      return null;
    }
  }

  void clear() {
    if (_sessionUser == null && _dashboard == null && _recipients.isEmpty) {
      _bootstrapErrorMessage = null;
      _recipientsErrorMessage = null;
      _transferErrorMessage = null;
      return;
    }

    _sessionUser = null;
    _dashboard = null;
    _receiverDashboard = null;
    _recipients = const [];
    _bootstrapErrorMessage = null;
    _recipientsErrorMessage = null;
    _transferErrorMessage = null;
    notifyListeners();
  }

  String _requireSessionToken() {
    final sessionToken = AuthService().sessionToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      throw StateError('Auth session is missing. Please sign in again.');
    }
    return sessionToken;
  }

  String _readableError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
