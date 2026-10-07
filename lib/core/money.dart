/// Formats an amount in poisha as whole taka, e.g. 1842000 -> ৳18,420
String formatTaka(int poisha) {
  final digits = (poisha ~/ 100).toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '৳$buffer';
}