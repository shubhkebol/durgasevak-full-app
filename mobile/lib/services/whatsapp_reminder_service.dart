import 'package:url_launcher/url_launcher.dart';

class WhatsAppReminderService {
  static final WhatsAppReminderService instance =
      WhatsAppReminderService._internal();

  WhatsAppReminderService._internal();

  static Future<bool> openWhatsAppChat({
    required String phoneNumber,
    required String message,
  }) {
    return instance.sendReminder(phoneNumber: phoneNumber, message: message);
  }

  /// Clean and format phone number for WhatsApp wa.me link.
  /// Returns a normalized number prefixed with country code (e.g., "919876543210").
  String? formatPhoneNumber(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    // If starts with 0 and followed by 10 digits
    if (digits.length == 11 && digits.startsWith('0')) {
      return '91${digits.substring(1)}';
    }

    // Standard 10-digit Indian mobile number
    if (digits.length == 10) {
      return '91$digits';
    }

    // Already includes 91 (12 digits)
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits;
    }

    // Fallback: if more than 10 digits, assume country code is already included
    if (digits.length > 10) {
      return digits;
    }

    // Default prepend 91 for shorter entries
    return '91$digits';
  }

  /// Check if the phone number looks valid (at least 10 digits).
  bool isValidPhoneNumber(String? raw) {
    if (raw == null) return false;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }

  /// Build the WhatsApp reminder message.
  String buildReminderMessage({
    required String memberName,
    required List<String> pendingMonths,
    double monthlyAmount = 100.0,
    String? additionalNote,
  }) {
    final buffer = StringBuffer();
    final totalAmount = (pendingMonths.length * monthlyAmount).toInt();
    final perMonthStr = monthlyAmount == monthlyAmount.roundToDouble()
        ? monthlyAmount.toInt().toString()
        : monthlyAmount.toStringAsFixed(2);

    buffer.writeln('जय शिवराय $memberName,');
    buffer.writeln();
    buffer.writeln(
      'दुर्गसेवक परिवारातर्फे विनंती की आपल्या खालील महिन्यांची मासिक वर्गणी (दरमहा ₹$perMonthStr/-) प्रलंबित आहे:',
    );
    buffer.writeln();

    for (final month in pendingMonths) {
      buffer.writeln('• $month : ₹$perMonthStr/-');
    }

    buffer.writeln();
    buffer.writeln('💰 एकूण प्रलंबित वर्गणी: ₹$totalAmount/-');

    if (additionalNote != null && additionalNote.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln(additionalNote.trim());
    }

    buffer.writeln();
    buffer.writeln('कृपया लवकरात लवकर जमा करावी. धन्यवाद!');
    buffer.write('🚩 दुर्गसेवक परिवार 🚩');

    return buffer.toString();
  }

  /// Launch WhatsApp with prefilled message.
  /// Primary target: `https://wa.me/+91<mobile>?text=<encoded>`
  Future<bool> sendReminder({
    required String phoneNumber,
    required String message,
  }) async {
    final formattedNumber = formatPhoneNumber(phoneNumber);
    if (formattedNumber == null || formattedNumber.isEmpty) {
      return false;
    }

    final encodedMessage = Uri.encodeComponent(message);

    // User requested format: https://wa.me/+91...
    final waMeUrl = Uri.parse(
      'https://wa.me/+$formattedNumber?text=$encodedMessage',
    );
    final nativeWhatsappUrl = Uri.parse(
      'whatsapp://send?phone=$formattedNumber&text=$encodedMessage',
    );

    try {
      // First try native whatsapp scheme if possible
      if (await canLaunchUrl(nativeWhatsappUrl)) {
        return await launchUrl(
          nativeWhatsappUrl,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      // Fallback to https wa.me
    }

    try {
      return await launchUrl(waMeUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Final attempt with platform default
      return await launchUrl(waMeUrl, mode: LaunchMode.platformDefault);
    }
  }
}
