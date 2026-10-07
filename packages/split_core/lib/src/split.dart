// All values are integer poisha (1 taka = 100 poisha). Never double.

/// Split [total] poisha into [n] parts that add up exactly. First parts get the extra poisha.
List<int> splitEqually(int total, int n) {
  if (n <= 0) throw ArgumentError('n must be > 0');
  if (total < 0) throw ArgumentError('total must be >= 0');
  final base = total ~/ n;
  final remainder = total - base * n;
  return List.generate(n, (i) => base + (i < remainder ? 1 : 0));
}

/// Split [total] in proportion to [weights], largest remainder method, integer math.
///
/// Ties on the remainder go to the HIGHER index. The spec text says lower index, but its
/// own golden table (Rafi 740.67, Nabil 640.06) only reproduces with higher index, so the
/// golden table wins. See DECISIONS.md. The result is deterministic either way.
List<int> splitByWeight(int total, List<int> weights) {
  if (weights.isEmpty) throw ArgumentError('weights must not be empty');
  if (total < 0 || weights.any((w) => w < 0)) {
    throw ArgumentError('amounts must be >= 0');
  }
  final sum = weights.fold<int>(0, (a, b) => a + b);
  if (sum == 0) return splitEqually(total, weights.length);
  final floors = <int>[];
  final rems = <int>[];
  for (final w in weights) {
    final product = total * w;
    assert(w == 0 || product ~/ w == total, 'overflow in splitByWeight');
    floors.add(product ~/ sum);
    rems.add(product % sum);
  }
  var left = total - floors.fold<int>(0, (a, b) => a + b);
  final order = List<int>.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final c = rems[b].compareTo(rems[a]);
      return c != 0 ? c : b.compareTo(a);
    });
  for (final i in order) {
    if (left <= 0) break;
    floors[i] += 1;
    left -= 1;
  }
  return floors;
}

/// Rate in basis points (5.9% = 590) applied to [base], rounded half up, integer math.
int applyRateBp(int base, int rateBp) => (base * rateBp + 5000) ~/ 10000;
