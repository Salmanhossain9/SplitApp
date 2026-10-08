import 'dart:math' as math;

import 'package:split_core/split_core.dart';

import 'scan_models.dart';

/// One line of text the OCR found, with where it sits on the photo (pixels).
class OcrLine {
  const OcrLine(
    this.text, {
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.angle = 0,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// How much the text baseline is tilted, in radians (positive = clockwise). OCR engines give
  /// this through the line's corner points; a photo taken at a slant has it on every line.
  final double angle;

  double get midY => (top + bottom) / 2;
  double get height => math.max(1, bottom - top);
}

/// Turns raw OCR lines from a Bangladeshi restaurant receipt into items, VAT, service charge
/// and total. Pure Dart so it is unit tested without a phone.
///
/// OCR engines often split one printed row ("Coke x3 ........ 270") into two pieces, the name
/// on the left and the price on the right, so rows are rebuilt from the lines' positions first.
/// The person always reviews and edits the result, so it favours skipping a doubtful line over
/// inventing an item.
class ReceiptParser {
  ReceiptParser._();

  static const _bangla = '০১২৩৪৫৬৭৮৯';

  // Rows that are never items, anywhere on the receipt.
  static final _ignore = RegExp(
    r'\b(invoice|receipt|bill\s*(no|number|#)|order|table|waiter|cashier|server|served|date|time|tel|phone|mobile|cell|hotline|'
    r'www|email|thank|thanks|visit|welcome|address|road|avenue|dhaka|chattogram|chittagong|sylhet|khulna|rajshahi|'
    r'bin|mushak|reg|trn|token|guests?|pax|block|plot|house|flat|floor|level|sector|shopping|square|squre|plaza|tower|customer|cash|change|tender|tendered|visa|mastercard|debit|credit|bkash|nagad|rocket|'
    r'paid|payment|balance|description|particulars|powered|software|pos|counter|terminal|session|operator)\b|\.com\b|@',
    caseSensitive: false,
  );
  static final _header = RegExp(r'\b(item|description|particulars|name)\b.*\b(qty|quantity|price|rate|amount|total)\b|\bqty\b.*\b(price|rate|amount)\b|\bname\b.*\bprice\b', caseSensitive: false);
  static final _subtotal = RegExp(r'sub\s*-?\s*total|total\s*before|food\s*(total|amount)|sales?\s*total', caseSensitive: false);
  static final _total = RegExp(r'\btotal\b|payable|amount\s*due|bill\s*amount|grand|net\s*amount|remaining\s*amount|gross\s*amount|to\s*pay', caseSensitive: false);
  static final _notATotal = RegExp(r'\b(items?|qty|quantity|pax|guests?|persons?|covers?)\b', caseSensitive: false);
  static final _grand = RegExp(r'grand|net|gross|remaining|payable|to\s*pay|amount\s*due', caseSensitive: false);
  static final _vat = RegExp(r'\bvat\b|v\.a\.t|\btax\b|\bgst\b|\bcgst\b|\bsgst\b', caseSensitive: false);
  static final _service = RegExp(r'service|\bsvc\b|\bs\.?\s*charge\b|\bsc\b', caseSensitive: false);
  static final _discount = RegExp(r'discount|\bdisc\b|promo|coupon|\boff\b');
  static final _adjust = RegExp(r'discount|\bdisc\b|promo|coupon|round|adjust|\boff\b|\btip\b|delivery', caseSensitive: false);
  static final _date = RegExp(r'\b\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}\b|\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}:\d{2}\b');

  static final _currency = RegExp(r'৳|\bTk\b\.?|\bBDT\b|/-|\bTaka\b', caseSensitive: false);
  static final _leaders = RegExp(r'\.{2,}|-{2,}|_{2,}|={2,}|[·•|]+');
  static final _number = RegExp(r'(?<![A-Za-z\d.])(\d{1,3}(?:,\d{3})+|\d{1,2}(?:,\d{2})+,\d{3}|\d+)(\.\d+)?(\s*%)?(?![A-Za-z\d])');

  static ScanResult parse(List<OcrLine> lines) {
    final rows = _rows(lines);
    final parsed = [for (var i = 0; i < rows.length; i++) _classify(rows[i], i)];
    _mergeSplitRows(parsed);

    // Items live above the first subtotal/total/vat/service row. If the layout is odd and that
    // leaves nothing, fall back to every plausible row.
    final firstSummary = parsed.indexWhere((r) => _summaryKinds.contains(r.kind));
    // When the printed column header ("Qty Item Name Price") was read, nothing above it is a dish.
    final header = parsed.indexWhere((r) => r.kind == _Kind.header);
    List<_Row> candidates(bool limit) => [
          for (final r in parsed)
            if (r.kind == _Kind.item &&
                (!limit || firstSummary == -1 || r.index < firstSummary) &&
                (!limit || header == -1 || r.index > header))
              r,
        ];
    var itemRows = candidates(true);
    if (itemRows.isEmpty) itemRows = candidates(false);

    final items = <ScannedItem>[for (final r in itemRows) ?_toItem(r)];

    final summary = firstSummary == -1 ? const <_Row>[] : parsed.sublist(firstSummary);
    int? sum(_Kind k) {
      final amounts = [for (final r in summary) if (r.kind == k && r.amount != null) r.amount!];
      return amounts.isEmpty ? null : amounts.fold<int>(0, (a, b) => a + b);
    }

    final totals = [for (final r in summary) if (r.kind == _Kind.total && r.amount != null) r];
    int? total;
    if (totals.isNotEmpty) {
      final grand = totals.where((r) => _grand.hasMatch(r.label)).toList();
      total = (grand.isNotEmpty ? grand.last : totals.last).amount;
    }

    final firstItemIndex = itemRows.isEmpty ? parsed.length : itemRows.first.index;
    var vat = sum(_Kind.vat);
    var service = sum(_Kind.service);
    final itemsSum = items.fold<int>(0, (a, i) => a + i.qty * i.unitPrice);
    if (total != null && itemsSum > 0 && itemsSum == total) {
      // The printed total equals the items, so the VAT line only shows how much of it is tax.
      // Adding it on top would charge it twice.
      vat = null;
      service = null;
    }
    return ScanResult(
      place: _place(parsed.where((r) => r.index < firstItemIndex).toList()),
      items: items,
      vat: vat,
      service: service,
      total: total,
    );
  }

  // ---- rows ------------------------------------------------------------------

  /// Group OCR lines that sit on the same printed row, left to right.
  static List<String> _rows(List<OcrLine> lines) {
    final usable = [for (final l in lines) if (l.text.trim().isNotEmpty) l];
    // A tilted photo makes the right end of a row sit lower (or higher) than the left end.
    // Take the page's tilt from the lines and straighten the vertical positions with it.
    final tilt = _median([for (final l in usable) l.angle]);
    final slope = math.tan(tilt);
    double y(OcrLine l) => l.midY - slope * (l.left + l.right) / 2;
    usable.sort((a, b) => y(a).compareTo(y(b)));
    final groups = <List<OcrLine>>[];
    for (final l in usable) {
      if (groups.isNotEmpty) {
        final g = groups.last;
        final mid = g.fold<double>(0, (a, b) => a + y(b)) / g.length;
        final h = g.fold<double>(0, (a, b) => a + b.height) / g.length;
        if ((y(l) - mid).abs() <= 0.5 * math.min(h, l.height)) {
          g.add(l);
          continue;
        }
      }
      groups.add([l]);
    }
    return [
      for (final g in groups) (g..sort((a, b) => a.left.compareTo(b.left))).map((l) => l.text.trim()).join(' '),
    ];
  }

  static double _median(List<double> xs) {
    if (xs.isEmpty) return 0;
    final s = [...xs]..sort();
    return s[s.length ~/ 2];
  }

  static String _normalize(String raw) {
    var s = raw.replaceAll(RegExp(r'[×✕✖]'), 'x');
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(_bangla[i], '$i');
    }
    s = s.replaceAll(_currency, ' ').replaceAll(_leaders, ' ');
    // OCR mistakes in amounts: "1, 200" (space after the thousands comma) and "640,00"
    // (decimal comma).
    s = s.replaceAllMapped(RegExp(r'(\d),\s+(?=\d)'), (m) => '${m[1]},');
    s = s.replaceAllMapped(RegExp(r'(?<=\d),(\d{2})(?![\d,])'), (m) => '.${m[1]}');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ---- one row ---------------------------------------------------------------

  static _Row _classify(String raw, int index) {
    var text = _normalize(raw);
    // "G u e s t B i l l": letters spaced out by the printer. Joined so it can be recognised.
    final spaced = RegExp(r'(?<![A-Za-z])[A-Za-z](?: [A-Za-z]){2,}(?![A-Za-z])').firstMatch(text);
    var spacedHeading = false;
    if (spaced != null) {
      final joined = spaced.group(0)!.replaceAll(' ', '');
      spacedHeading = RegExp(r'guest|bill|invoice|table|waiter|date|time|receipt|order|customer', caseSensitive: false).hasMatch(joined);
      text = text.replaceRange(spaced.start, spaced.end, joined);
    }
    final row = _Row(index, text);
    final lower = text.toLowerCase();
    if (text.isEmpty) return row;

    // Quantity written next to the name: "3 x 90", "x3", "3x", "qty 3".
    int? markerQty;
    // "550.00 x 2": the unit price first, then the quantity (a decimal price, a whole quantity).
    // The row's amount becomes the line total, 1100.00, so it reads like any other row.
    final unitTimes = RegExp(r'(\d+\.\d{1,2})\s*x\s*(\d{1,3})\b(?![.,]?\d)', caseSensitive: false).firstMatch(text);
    if (unitTimes != null) {
      final unit = parsePoisha(unitTimes.group(1)!);
      final qty = int.parse(unitTimes.group(2)!);
      if (unit != null && qty >= 1) {
        final line = unit * qty;
        text = text.replaceRange(unitTimes.start, unitTimes.end, ' ${line ~/ 100}.${(line % 100).toString().padLeft(2, '0')} ');
        markerQty = qty;
        row.hasUnitTimes = true;
      }
    }
    final qtyRate = RegExp(r'(\d{1,3})\s*[xX@]\s*(\d+(?:\.\d+)?)(?=\s+\d)').firstMatch(text);
    if (markerQty != null) {
      // Already read as "unit x qty".
    } else if (qtyRate != null) {
      markerQty = int.tryParse(qtyRate.group(1)!);
      text = text.replaceRange(qtyRate.start, qtyRate.end, ' ');
    } else {
      final m = RegExp(r'(?:\b[xX]\s*(\d{1,3})\b|\b(\d{1,3})\s*[xX]\b|\bqty\.?\s*:?\s*(\d{1,3})\b)', caseSensitive: false).firstMatch(text);
      if (m != null) {
        markerQty = int.tryParse(m.group(1) ?? m.group(2) ?? m.group(3)!);
        text = text.replaceRange(m.start, m.end, ' ');
      }
    }

    // The numeric tail: consecutive numbers at the end of the row ("3 90.00 270.00").
    final matches = _number.allMatches(text).toList();
    final tail = <RegExpMatch>[];
    var end = text.length;
    for (var i = matches.length - 1; i >= 0; i--) {
      final m = matches[i];
      final gap = text.substring(m.end, end);
      if (RegExp(r'^[\s=@:]*$').hasMatch(gap)) {
        tail.insert(0, m);
        end = m.start;
      } else {
        break;
      }
    }
    final values = <({int poisha, bool decimal})>[
      for (final m in tail)
        if (m.group(3) == null)
          if (parsePoisha('${m.group(1)}${m.group(2) ?? ''}') case final p?) (poisha: p, decimal: m.group(2) != null),
    ];
    var label = text.substring(0, tail.isEmpty ? text.length : tail.first.start);
    label = label.replaceAll(RegExp(r'\d+(\.\d+)?\s*%'), ' ');
    row.label = _cleanName(label);
    row.markerQty = markerQty;
    row.values = values;
    row.amount = values.isEmpty ? null : values.last.poisha;
    final letters = RegExp(r'[A-Za-zঀ-৿]').allMatches(row.label).length;
    row.letters = letters;

    final l = row.label.toLowerCase();
    row.continuation = RegExp(r'^[.,]\s*\w|^[a-z]').hasMatch(text);
    if (_header.hasMatch(lower) && row.amount == null) {
      row.kind = _Kind.header;
    } else if (spacedHeading || row.label.contains(':')) {
      row.kind = _Kind.ignored; // "Table: Outdoor_3", "Waiter:Rayhan", "G u e s t B i l l"
    } else if (_discount.hasMatch(l) && !_grand.hasMatch(l)) {
      row.kind = _Kind.adjust; // "Total Discount(%)" is not the total
    } else if (_vat.hasMatch(l) &&
        !_grand.hasMatch(l) &&
        !RegExp(r'\b(incl|including|with|after|plus|pay|payable)\b|\breg|\bbin\b|\bno\b', caseSensitive: false).hasMatch(l)) {
      row.kind = _Kind.vat; // "VAT Total(5%)" is VAT, not the total
    } else if (_subtotal.hasMatch(l)) {
      row.kind = _Kind.subtotal;
    } else if (_total.hasMatch(l) && _notATotal.hasMatch(l)) {
      row.kind = _Kind.ignored; // "Total Items: 4"
    } else if (_total.hasMatch(l)) {
      row.kind = _Kind.total;
    } else if (_vat.hasMatch(l) && !RegExp(r'\breg|\bbin\b|\bno\b', caseSensitive: false).hasMatch(l)) {
      row.kind = _Kind.vat;
    } else if (_service.hasMatch(l)) {
      row.kind = _Kind.service;
    } else if (_adjust.hasMatch(l)) {
      row.kind = _Kind.adjust;
    } else if (_ignore.hasMatch(lower) || _header.hasMatch(lower) || _date.hasMatch(lower) || letters < 2) {
      row.kind = letters >= 2 ? _Kind.ignored : _Kind.text;
    } else {
      row.kind = _Kind.item;
    }
    if (row.kind == _Kind.ignored && row.label.contains(':') && _vat.hasMatch(l)) row.kind = _Kind.vat;
    // A row with a label but nothing priced is text (a wrapped name or a heading).
    if (row.kind == _Kind.item && row.amount == null) row.kind = _Kind.text;
    return row;
  }

  /// A wrapped name ("Chicken burger" on one row, "345" alone on the next) becomes one row.
  static void _mergeSplitRows(List<_Row> rows) {
    for (var i = 0; i + 1 < rows.length; i++) {
      final a = rows[i], b = rows[i + 1];
      // "Jalapeno Pizza 550.00 x 1" then "SMALL 550.00": the second row only names the size and
      // repeats the line total. Only after a "unit x qty" row, so two dishes at one price stay two.
      if (a.kind == _Kind.item &&
          a.hasUnitTimes &&
          b.kind == _Kind.item &&
          b.amount != null &&
          b.amount == a.amount &&
          b.label.split(' ').length <= 2 &&
          !RegExp(r'^\d{1,2}\s+[A-Za-z]').hasMatch(b.label)) {
        a.label = '${a.label} ${b.label}';
        b.kind = _Kind.merged;
        continue;
      }
      // "1 Chocolate Brownie Cream" then ".REGULAR 499.00 499.00": a printed name that wrapped,
      // its second half carrying the price. The first half starts with the quantity.
      final aIsQtyName = a.kind == _Kind.text &&
          a.amount == null &&
          RegExp(r'^\d{1,2}\s+[A-Za-z]').hasMatch(a.label) &&
          !_ignore.hasMatch(a.label.toLowerCase());
      final bIsRest = b.kind == _Kind.item && b.continuation && !RegExp(r'^\d{1,2}\s+[A-Za-z]').hasMatch(b.label);
      if (aIsQtyName && bIsRest) {
        // Cut mid word ("French T" + "oast"): no space between the halves.
        final midWord = RegExp(r'\s[A-Za-z]$').hasMatch(a.label) && RegExp(r'^[a-z]').hasMatch(b.label);
        a
          ..kind = _Kind.item
          ..label = midWord ? '${a.label}${b.label}' : '${a.label} ${b.label}'
          ..values = b.values
          ..amount = b.amount
          ..markerQty = a.markerQty ?? b.markerQty;
        b.kind = _Kind.merged;
        continue;
      }
      // "Mutton 320.00 1 320.00" then "Khichuri (Half)": in a table with rate, qty and price columns
      // the rest of a long name wraps onto the row below the numbers.
      if (a.kind == _Kind.item &&
          a.values.length >= 3 &&
          b.kind == _Kind.text &&
          b.letters >= 2 &&
          b.amount == null &&
          !_ignore.hasMatch(b.label.toLowerCase())) {
        a.label = '${a.label} ${b.label}';
        b.kind = _Kind.merged;
        continue;
      }
      final aIsNameOnly = a.kind == _Kind.text && a.letters >= 2 && a.amount == null && !_ignore.hasMatch(a.label.toLowerCase());
      final bIsPriceOnly = b.kind == _Kind.text && b.letters < 2 && b.amount != null;
      if (aIsNameOnly && bIsPriceOnly) {
        a
          ..kind = _Kind.item
          ..values = b.values
          ..amount = b.amount
          ..markerQty = a.markerQty ?? b.markerQty;
        b.kind = _Kind.merged;
      }
    }
  }

  static ScannedItem? _toItem(_Row r) {
    final values = r.values;
    if (values.isEmpty) return null;
    final name = r.label;
    final total = values.last.poisha;
    if (total <= 0 || total > 100000000) return null;
    if (name.replaceAll(RegExp(r'[^A-Za-zঀ-৿]'), '').length < 2) return null;

    var qty = r.markerQty ?? 1;
    var label = name;
    if (r.markerQty == null) {
      if (values.length >= 3) {
        // "Coke 3 90.00 270.00": quantity, rate, amount.
        final q = values[values.length - 3];
        final rate = values[values.length - 2];
        if (!q.decimal && q.poisha % 100 == 0) {
          final k = q.poisha ~/ 100;
          if (k >= 1 && k <= 50 && (k * rate.poisha - total).abs() <= 100) qty = k;
        }
        if (qty == 1) {
          // "Mutton 320.00 1 320.00": rate, then quantity, then amount.
          final rate2 = values[values.length - 3];
          final q2 = values[values.length - 2];
          if (!q2.decimal && q2.poisha % 100 == 0) {
            final k = q2.poisha ~/ 100;
            if (k >= 1 && k <= 50 && (k * rate2.poisha - total).abs() <= 100) qty = k;
          }
        }
      } else if (values.length == 2) {
        final a = values.first, b = values.last;
        if (!a.decimal && a.poisha % 100 == 0 && a.poisha ~/ 100 >= 1 && a.poisha ~/ 100 <= 20 && b.poisha % (a.poisha ~/ 100) == 0) {
          qty = a.poisha ~/ 100; // "Fries 2 480"
        } else if (a.poisha > 0 && b.poisha % a.poisha == 0 && b.poisha ~/ a.poisha >= 1 && b.poisha ~/ a.poisha <= 20) {
          qty = b.poisha ~/ a.poisha; // "Coke 90.00 270.00": rate then amount
        }
      }
    }
    // A leading number is a serial column ("1  Chicken Biryani ...") or a quantity
    // ("2 Chicken burger 690"). It is a quantity only when it is the sole hint and divides the
    // line total; otherwise it is dropped as a serial number.
    final lead = RegExp(r'^(\d{1,2})\s+(?=[A-Za-z])').firstMatch(label);
    if (lead != null) {
      final n = int.parse(lead.group(1)!);
      final soleHint = r.markerQty == null && qty == 1 && values.length == 1;
      final rateMatches = r.markerQty == null && qty == 1 && values.length == 2 && values.first.poisha * n == total;
      if ((soleHint || rateMatches) && n >= 1 && total % n == 0) {
        qty = n;
      }
      label = label.substring(lead.end);
    }
    label = _cleanName(label);
    if (label.isEmpty) return null;
    qty = qty.clamp(1, 99);
    // Keep the line total exact: when it does not divide by the quantity, one unit at the
    // full price so the subtotal still matches the receipt.
    if (qty > 1 && total % qty != 0) {
      return ScannedItem(name: _clip('$label x$qty'), qty: 1, unitPrice: total);
    }
    return ScannedItem(name: _clip(label), qty: qty, unitPrice: total ~/ qty);
  }

  static String _clip(String s) => s.length > 80 ? s.substring(0, 80) : s;

  static String _cleanName(String raw) {
    var s = raw.replaceAll(RegExp(r'^\s*\d{1,2}[.)]\s+'), ' ');
    s = s.replaceAll(RegExp(r'^[\s.:,\-•*#]+|[\s.:,\-=@•*#]+$'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _titleIfShouting(s);
  }

  /// "CHICKEN BURGER" -> "Chicken Burger"; mixed case is left alone.
  static String _titleIfShouting(String s) {
    final letters = s.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length < 4 || letters != letters.toUpperCase()) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  // ---- place -------------------------------------------------------------------

  /// The first clean text row above the items, usually the restaurant's name.
  static String? _place(List<_Row> header) {
    for (final r in header) {
      final raw = r.text;
      final lower = raw.toLowerCase();
      final letters = RegExp(r'[A-Za-z]').allMatches(raw).length;
      final visible = raw.replaceAll(' ', '').length;
      if (letters < 3 || visible == 0 || letters / visible < 0.7) continue;
      if (_ignore.hasMatch(lower) || _date.hasMatch(lower) || _header.hasMatch(lower)) continue;
      return _titleIfShouting(_cleanName(raw));
    }
    return null;
  }
}

const _summaryKinds = {_Kind.subtotal, _Kind.total, _Kind.vat, _Kind.service, _Kind.adjust};

enum _Kind { text, ignored, header, item, subtotal, total, vat, service, adjust, merged }

class _Row {
  _Row(this.index, this.text);
  final int index;
  final String text;
  String label = '';
  int letters = 0;
  int? markerQty;
  bool hasUnitTimes = false; // printed as "unit price x qty"
  bool continuation = false; // starts like the tail of a wrapped name (".REGULAR", "cast")
  List<({int poisha, bool decimal})> values = const [];
  int? amount;
  _Kind kind = _Kind.text;
}
