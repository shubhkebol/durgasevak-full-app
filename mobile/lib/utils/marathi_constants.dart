class MarathiConstants {
  static const List<String> months = [
    'जानेवारी',
    'फेब्रुवारी',
    'मार्च',
    'एप्रिल',
    'मे',
    'जून',
    'जुलै',
    'ऑगस्ट',
    'सप्टेंबर',
    'ऑक्टोबर',
    'नोव्हेंबर',
    'डिसेंबर',
  ];

  static String getMonthName(int monthNumber) {
    if (monthNumber >= 1 && monthNumber <= 12) {
      return months[monthNumber - 1];
    }
    return '';
  }

  static String formatMonthYear(int month, int year) {
    return '${getMonthName(month)} $year';
  }

  static String formatMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length == 2) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null && month >= 1 && month <= 12) {
        return '${months[month - 1]} $year';
      }
    }
    return monthKey;
  }
}
