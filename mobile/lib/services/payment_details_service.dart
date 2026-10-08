import 'package:url_launcher/url_launcher.dart';

import '../models/payment_details.dart';
import 'sync_metadata_service.dart';

class PaymentDetailsService {
  static final PaymentDetailsService instance =
      PaymentDetailsService._internal();

  final SyncMetadataService _metadataService = SyncMetadataService.instance;

  PaymentDetailsService._internal();

  Future<PaymentDetails> loadDetails() async {
    final upiId = await _metadataService.get('payment_upi_id') ?? '';
    final payeeName =
        await _metadataService.get('payment_payee_name') ?? 'दुर्गसेवक';
    final qrBarcodeBase64 =
        await _metadataService.get('payment_qr_barcode_base64');
    final accountHolderName =
        await _metadataService.get('payment_account_holder_name') ?? '';
    final bankName = await _metadataService.get('payment_bank_name') ?? '';
    final accountNumber =
        await _metadataService.get('payment_account_number') ?? '';
    final ifscCode = await _metadataService.get('payment_ifsc_code') ?? '';
    final branch = await _metadataService.get('payment_branch') ?? '';
    final accountType =
        await _metadataService.get('payment_account_type') ??
        'बचत खाते (Savings)';

    return PaymentDetails(
      upiId: upiId,
      payeeName: payeeName,
      qrBarcodeBase64: qrBarcodeBase64,
      accountHolderName: accountHolderName,
      bankName: bankName,
      accountNumber: accountNumber,
      ifscCode: ifscCode,
      branch: branch,
      accountType: accountType,
    );
  }

  Future<void> saveDetails(PaymentDetails details) async {
    await _metadataService.set('payment_upi_id', details.upiId.trim());
    await _metadataService.set(
      'payment_payee_name',
      details.payeeName.trim().isEmpty ? 'दुर्गसेवक' : details.payeeName.trim(),
    );

    if (details.qrBarcodeBase64 != null &&
        details.qrBarcodeBase64!.trim().isNotEmpty) {
      await _metadataService.set(
        'payment_qr_barcode_base64',
        details.qrBarcodeBase64!.trim(),
      );
    } else {
      await _metadataService.remove('payment_qr_barcode_base64');
    }

    await _metadataService.set(
      'payment_account_holder_name',
      details.accountHolderName.trim(),
    );
    await _metadataService.set('payment_bank_name', details.bankName.trim());
    await _metadataService.set(
      'payment_account_number',
      details.accountNumber.trim(),
    );
    await _metadataService.set(
      'payment_ifsc_code',
      details.ifscCode.trim().toUpperCase(),
    );
    await _metadataService.set('payment_branch', details.branch.trim());
    await _metadataService.set(
      'payment_account_type',
      details.accountType.trim(),
    );
  }

  /// Launch UPI application installed on phone with prefilled parameters
  Future<bool> launchUpiPayment({
    required String upiId,
    required String payeeName,
    required double amount,
    String note = 'दुर्गसेवक देणगी',
  }) async {
    final cleanUpi = upiId.trim();
    if (cleanUpi.isEmpty) {
      return false;
    }

    final cleanPayee = Uri.encodeComponent(
      payeeName.trim().isEmpty ? 'दुर्गसेवक' : payeeName.trim(),
    );
    final amountFormatted = amount.toStringAsFixed(2);
    final encodedNote = Uri.encodeComponent(
      note.trim().isEmpty ? 'देणगी' : note.trim(),
    );

    final upiUrlString =
        'upi://pay?pa=$cleanUpi&pn=$cleanPayee&am=$amountFormatted&cu=INR&tn=$encodedNote';
    final uri = Uri.parse(upiUrlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Fallback: try launching directly even if canLaunchUrl returned false
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
