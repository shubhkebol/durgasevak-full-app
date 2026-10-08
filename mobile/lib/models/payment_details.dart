class PaymentDetails {
  final String upiId;
  final String payeeName;
  final String? qrBarcodeBase64;
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String branch;
  final String accountType;

  const PaymentDetails({
    this.upiId = '',
    this.payeeName = 'दुर्गसेवक',
    this.qrBarcodeBase64,
    this.accountHolderName = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.branch = '',
    this.accountType = 'बचत खाते (Savings)',
  });

  PaymentDetails copyWith({
    String? upiId,
    String? payeeName,
    String? qrBarcodeBase64,
    bool clearBarcode = false,
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? branch,
    String? accountType,
  }) {
    return PaymentDetails(
      upiId: upiId ?? this.upiId,
      payeeName: payeeName ?? this.payeeName,
      qrBarcodeBase64: clearBarcode ? null : (qrBarcodeBase64 ?? this.qrBarcodeBase64),
      accountHolderName: accountHolderName ?? this.accountHolderName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      branch: branch ?? this.branch,
      accountType: accountType ?? this.accountType,
    );
  }

  bool get hasUpiId => upiId.trim().isNotEmpty;
  bool get hasBarcode => qrBarcodeBase64 != null && qrBarcodeBase64!.trim().isNotEmpty;
  bool get hasBankDetails =>
      accountNumber.trim().isNotEmpty || bankName.trim().isNotEmpty;
}
