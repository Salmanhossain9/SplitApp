import 'package:flutter_test/flutter_test.dart';
import 'package:splitup/theme/tokens.dart';

void main() {
  test('text colour follows the pairing rules', () {
    expect(AppColors.onColor(AppColors.lavender), AppColors.white);
    expect(AppColors.onColor(AppColors.coral), AppColors.white);
    expect(AppColors.onColor(AppColors.navy), AppColors.white);
    expect(AppColors.onColor(AppColors.lime), AppColors.navy);
    expect(AppColors.onColor(AppColors.sky), AppColors.navy);
    expect(AppColors.onColor(AppColors.cream), AppColors.navy);
  });

  test('type styles carry the taka fallback font and the spec line heights', () {
    expect(AppType.celebrate72.fontFamilyFallback, contains('NotoSansBengali'));
    expect(AppType.hero50.height! * 50, closeTo(50, 0.001));
    expect(AppType.title24.height! * 24, closeTo(29, 0.001));
    expect(AppType.celebrate72.letterSpacing, -2.88);
  });

  test('bill cards cycle lavender, lime, sky, coral', () {
    expect(AppColors.billCardCycle, [
      AppColors.lavender,
      AppColors.lime,
      AppColors.sky,
      AppColors.coral,
    ]);
  });
}
