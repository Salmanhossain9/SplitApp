const takaSign = '৳';

/// "৳614", "৳740.67", "৳2,236". 3-digit grouping as in the designs (see DECISIONS.md).
/// Two decimals only when poisha is non-zero, unless [forceDecimals].
String formatTaka(int poisha, {bool forceDecimals = false}) {
  final p = moneyParts(poisha, forceDecimals: forceDecimals);
  return '${p.negative ? '-' : ''}$takaSign${p.whole}${p.decimals}';
}

class MoneyParts {
  const MoneyParts(this.negative, this.whole, this.decimals);
  final bool negative;

  /// Grouped whole taka, e.g. "2,236".
  final String whole;

  /// ".50" or "".
  final String decimals;
}

MoneyParts moneyParts(int poisha, {bool forceDecimals = false}) {
  final abs = poisha.abs();
  final whole = abs ~/ 100;
  final frac = abs % 100;
  final digits = whole.toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  final showDecimals = forceDecimals || frac != 0;
  return MoneyParts(
    poisha < 0,
    b.toString(),
    showDecimals ? '.${frac.toString().padLeft(2, '0')}' : '',
  );
}

const _banglaDigits = '০১২৩৪৫৬৭৮৯';

/// Parse typed taka into integer poisha with string math. "" -> 0, "412.5" -> 41250,
/// "1,200" -> 120000, Bangla digits ok. Invalid -> null. Digits past 2 decimals are dropped.
int? parsePoisha(String input) {
  var s = input.trim().replaceAll(RegExp('[,\\s৳]'), '');
  s = s.replaceAllMapped(
    RegExp('[০-৯]'),
    (m) => _banglaDigits.indexOf(m[0]!).toString(),
  );
  if (s.isEmpty) return 0;
  if (!RegExp(r'^\d*\.?\d*$').hasMatch(s) || s == '.') return null;
  final parts = s.split('.');
  final whole = parts[0].isEmpty ? 0 : int.tryParse(parts[0]);
  if (whole == null) return null;
  final fracStr = '${parts.length > 1 ? parts[1] : ''}00'.substring(0, 2);
  return whole * 100 + int.parse(fracStr);
}

/// Poisha to what an input field shows: 41250 -> "412.5", 41200 -> "412", 0 -> "".
String poishaToInput(int poisha) {
  if (poisha == 0) return '';
  final whole = poisha ~/ 100;
  final frac = poisha % 100;
  if (frac == 0) return '$whole';
  return '$whole.${frac.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}';
}

/// Parse a typed percentage ("5.9", "15") into basis points (590, 1500) with string math.
/// Empty -> 0. Invalid -> null. Digits past 2 decimals are dropped.
int? parseRateBp(String input) => parsePoisha(input.replaceAll('%', ''));

/// Basis points to the text a rate field shows: 590 -> "5.9", 1500 -> "15", 0 -> "0".
String rateBpToInput(int bp) {
  final s = poishaToInput(bp);
  return s.isEmpty ? '0' : s;
}
