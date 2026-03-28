import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ExchangeRateService {
  static const String _baseUrl = 'https://open.er-api.com/v6/latest';

  /// Fetch live exchange rate from [baseCurrency] to [targetCurrency]
  static Future<double?> getExchangeRate(
      {String baseCurrency = 'USD', String targetCurrency = 'INR'}) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$baseCurrency'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'success') {
          final rates = data['rates'] as Map<String, dynamic>;
          if (rates.containsKey(targetCurrency)) {
            return (rates[targetCurrency] as num).toDouble();
          }
        }
      }
      debugPrint("Failed to fetch exchange rate, status: \${response.statusCode}");
    } catch (e) {
      debugPrint("Error fetching exchange rate: \$e");
    }
    return null;
  }
}
