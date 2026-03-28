import 'package:postgres/postgres.dart';
import 'package:flutter/foundation.dart';

class NeonService {
  static final NeonService _instance = NeonService._internal();
  factory NeonService() => _instance;
  NeonService._internal();

  Connection? _connection;

  // The connection string from backend/.env
  // For production, this should not be hardcoded in the client app.
  final String _connectionUrl = "postgresql://neondb_owner:npg_pC6WZA3oGFlx@ep-rough-flower-a12s3a0d-pooler.ap-southeast-1.aws.neon.tech/neondb?sslmode=require";

  Future<Connection> _getConnection() async {
    if (_connection != null && _connection!.isOpen) {
      return _connection!;
    }
    
    // Convert URL to endpoint configuration
    final uri = Uri.parse(_connectionUrl);
    _connection = await Connection.open(
      Endpoint(
        host: uri.host,
        database: uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : 'neondb',
        username: uri.userInfo.split(':')[0],
        password: uri.userInfo.split(':')[1],
        port: uri.hasPort ? uri.port : 5432,
        isUnixSocket: false,
      ),
      settings: ConnectionSettings(
        sslMode: SslMode.require,
      ),
    );
    return _connection!;
  }

  /// Sync user to Neon DB
  Future<void> syncUser(String email, String walletAddress, String country) async {
    try {
      final conn = await _getConnection();
      
      // Check if user exists
      final result = await conn.execute(
        Sql.named('SELECT id FROM users WHERE email = @email'),
        parameters: {'email': email},
      );

      if (result.isEmpty) {
        // Create user with default 2000 mock transferred amount
        await conn.execute(
          Sql.named('''
            INSERT INTO users (email, wallet_address, country, amount_transferred)
            VALUES (@email, @wallet, @country, 2000.00)
          '''),
          parameters: {
            'email': email,
            'wallet': walletAddress,
            'country': country, // default or from auth
          },
        );
        debugPrint("User synced to NeonDB successfully.");
      } else {
        debugPrint("User already exists in NeonDB.");
      }
    } catch (e) {
      debugPrint("Error syncing user to Neon: \$e");
    }
  }

  /// Get total transferred amount for user
  Future<double> getAmountTransferred(String email) async {
    try {
      final conn = await _getConnection();
      final result = await conn.execute(
        Sql.named('SELECT amount_transferred FROM users WHERE email = @email'),
        parameters: {'email': email},
      );

      if (result.isNotEmpty) {
        final amountStr = result[0][0].toString();
        return double.tryParse(amountStr) ?? 0.0;
      }
    } catch (e) {
      debugPrint("Error fetching amount: \$e");
    }
    return 0.0; // default for unknown 
  }

  /// Mock a transfer transaction by updating the `amount_transferred`
  Future<bool> mockTransfer(String email, double amount) async {
    try {
      final conn = await _getConnection();
      
      // We just add amount to the existing quantity based on user request "add to it when user transfers any money"
      await conn.execute(
        Sql.named('''
          UPDATE users 
          SET amount_transferred = amount_transferred + @amount
          WHERE email = @email
        '''),
        parameters: {
          'email': email,
          'amount': amount,
        },
      );
      debugPrint("Mock transfer completed in NeonDB.");
      return true;
    } catch (e) {
      debugPrint("Error mocking transfer: \$e");
      return false;
    }
  }
}
