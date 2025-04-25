import 'dart:convert';
import 'package:http/http.dart' as http;

class TicketVerificationResult {
  final bool success;
  final bool valid;
  final String? checkedInTime;
  final String? message;

  TicketVerificationResult({
    required this.success,
    this.valid = false,
    this.checkedInTime,
    this.message,
  });
}

class TicketApiService {
  static const String baseUrl = 'http://app.sweatshop.co.za/wp-json/ticket-manager/v1/verify/';

  static Future<TicketVerificationResult> verifyTicket(String code) async {
    final url = Uri.parse('$baseUrl?code=$code');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bool valid = data['valid'] == true;
        final String? checkedInTime = data['checked_in_time']?.toString();
        final String? message = data['message']?.toString();
        return TicketVerificationResult(
          success: true,
          valid: valid,
          checkedInTime: checkedInTime,
          message: message,
        );
      } else if (response.statusCode == 404) {
        return TicketVerificationResult(
          success: false,
          message: 'Invalid ticket',
        );
      } else {
        return TicketVerificationResult(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      return TicketVerificationResult(
        success: false,
        message: 'Network error: $e',
      );
    }
  }
}
