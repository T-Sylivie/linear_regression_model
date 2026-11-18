import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message);

  final String message;
}

class ApiService {
  static const baseUrl = 'https://nairobi-delivery-time-api.onrender.com';

  static Future<double> predict(Map<String, Object> inputs, Map<String, String> labels) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(inputs),
        )
        .timeout(const Duration(seconds: 90));

    final body = _decode(response.body);

    if (response.statusCode == 200 && body is Map) {
      return (body['predicted_delivery_time_minutes'] as num).toDouble();
    }

    if (response.statusCode == 422 && body is Map && body['detail'] is List) {
      final errors = (body['detail'] as List).map((error) {
        final field = (error['loc'] as List).last.toString();
        return '${labels[field] ?? field}: ${error['msg']}';
      });
      throw ApiException(errors.join('\n'));
    }

    throw ApiException('The server returned an error (${response.statusCode}). Please try again.');
  }

  static dynamic _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}