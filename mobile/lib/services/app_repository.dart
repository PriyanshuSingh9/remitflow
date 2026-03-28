import '../models/app_models.dart';
import 'api_client.dart';

class AppRepository {
  AppRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<SessionUser> fetchCurrentUser({required String sessionToken}) async {
    final response = await _apiClient.getJson('/auth/me', sessionToken: sessionToken);
    return SessionUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<DashboardData> fetchDashboard({required String sessionToken}) async {
    final response = await _apiClient.getJson('/me/dashboard', sessionToken: sessionToken);
    return DashboardData.fromJson(response);
  }

  Future<List<RecipientSummary>> searchRecipients({
    required String sessionToken,
    required String query,
  }) async {
    final response = await _apiClient.getJson(
      '/recipients',
      sessionToken: sessionToken,
      queryParameters: query.isEmpty ? null : {'q': query},
    );

    return (response['recipients'] as List<dynamic>? ?? const [])
        .map((item) => RecipientSummary.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<TransferReceipt> createTransfer({
    required String sessionToken,
    required String recipientId,
    required double amountUsd,
  }) async {
    final response = await _apiClient.postJson(
      '/transfers',
      sessionToken: sessionToken,
      body: {
        'recipientId': recipientId,
        'amountUsd': amountUsd,
      },
    );

    return TransferReceipt.fromJson(response);
  }
}
