class SessionUser {
  const SessionUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.phoneNumber,
    required this.walletAddress,
    required this.country,
    required this.availableBalanceUsd,
    required this.lifetimeSavingsUsd,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final String walletAddress;
  final String country;
  final double availableBalanceUsd;
  final double lifetimeSavingsUsd;

  String get preferredName {
    final trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return email.split('@').first;
  }

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      walletAddress: json['walletAddress'] as String,
      country: json['country'] as String? ?? 'US',
      availableBalanceUsd:
          (json['availableBalanceUsd'] as num?)?.toDouble() ?? 0,
      lifetimeSavingsUsd: (json['lifetimeSavingsUsd'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ExchangeRateData {
  const ExchangeRateData({
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.rate,
    required this.cheaperPercentage,
    required this.asOf,
  });

  final String baseCurrency;
  final String quoteCurrency;
  final double rate;
  final double cheaperPercentage;
  final DateTime asOf;

  factory ExchangeRateData.fromJson(Map<String, dynamic> json) {
    return ExchangeRateData(
      baseCurrency: json['baseCurrency'] as String,
      quoteCurrency: json['quoteCurrency'] as String,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      cheaperPercentage: (json['cheaperPercentage'] as num?)?.toDouble() ?? 0,
      asOf: DateTime.parse(json['asOf'] as String),
    );
  }
}

class RecipientSummary {
  const RecipientSummary({
    required this.id,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.phoneNumber,
    required this.country,
  });

  final String id;
  final String? displayName;
  final String email;
  final String? photoUrl;
  final String? phoneNumber;
  final String country;

  String get preferredName {
    final trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return email.split('@').first;
  }

  factory RecipientSummary.fromJson(Map<String, dynamic> json) {
    return RecipientSummary(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      country: json['country'] as String? ?? 'US',
    );
  }
}

class TransactionSummary {
  const TransactionSummary({
    required this.id,
    required this.direction,
    required this.counterparty,
    required this.amountUsd,
    required this.amountUsdc,
    required this.amountInr,
    required this.feeUsd,
    required this.txHash,
    required this.status,
    required this.createdAt,
    required this.completedAt,
  });

  final String id;
  final String direction;
  final RecipientSummary counterparty;
  final double amountUsd;
  final double amountUsdc;
  final double amountInr;
  final double feeUsd;
  final String? txHash;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isSent => direction == 'sent';

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      id: json['id'] as String,
      direction: json['direction'] as String,
      counterparty: RecipientSummary.fromJson(
        json['counterparty'] as Map<String, dynamic>,
      ),
      amountUsd: (json['amountUsd'] as num?)?.toDouble() ?? 0,
      amountUsdc: (json['amountUsdc'] as num?)?.toDouble() ?? 0,
      amountInr: (json['amountInr'] as num?)?.toDouble() ?? 0,
      feeUsd: (json['feeUsd'] as num?)?.toDouble() ?? 0,
      txHash: json['txHash'] as String?,
      status: (json['status'] as String?) ?? 'completed',
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.user,
    required this.exchangeRate,
    required this.recentTransactions,
  });

  final SessionUser user;
  final ExchangeRateData exchangeRate;
  final List<TransactionSummary> recentTransactions;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
      exchangeRate: ExchangeRateData.fromJson(
        json['exchangeRate'] as Map<String, dynamic>,
      ),
      recentTransactions:
          (json['recentTransactions'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    TransactionSummary.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false),
    );
  }
}

class TransferReceipt {
  const TransferReceipt({
    required this.transaction,
    required this.senderBalanceAfter,
  });

  final TransactionSummary transaction;
  final double senderBalanceAfter;

  factory TransferReceipt.fromJson(Map<String, dynamic> json) {
    return TransferReceipt(
      transaction: TransactionSummary.fromJson(
        json['transaction'] as Map<String, dynamic>,
      ),
      senderBalanceAfter: (json['senderBalanceAfter'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReceiverDashboardData {
  const ReceiverDashboardData({
    required this.user,
    required this.totalReceivedInr,
    required this.receivedTransactions,
  });

  final SessionUser user;
  final double totalReceivedInr;
  final List<TransactionSummary> receivedTransactions;

  factory ReceiverDashboardData.fromJson(Map<String, dynamic> json) {
    return ReceiverDashboardData(
      user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
      totalReceivedInr: (json['totalReceivedInr'] as num?)?.toDouble() ?? 0,
      receivedTransactions:
          (json['receivedTransactions'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    TransactionSummary.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false),
    );
  }
}
