import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitbit/features/gallery/gallery_screen.dart';
import 'package:splitbit/theme/app_theme.dart';
import 'package:splitbit/theme/tokens.dart';

/// One golden per gallery section, rendered in a 390 wide frame like the design.
void main() {
  for (final section in gallerySections) {
    testWidgets('golden: ${section.title}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1400);
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: key,
                  child: Container(
                    width: 390,
                    color: AppColors.cream,
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    child: section.builder(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/${section.title.replaceAll(' ', '_')}.png'),
      );
    });
  }
}
