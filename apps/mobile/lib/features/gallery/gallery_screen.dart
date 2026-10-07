import 'package:flutter/material.dart';
import 'package:split_core/split_core.dart';

import '../../theme/tokens.dart';

/// Debug-only visual QA page. Grows with every widget added in milestone 2.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          children: [
            Text('type', style: AppType.display36),
            const SizedBox(height: AppSpacing.s16),
            Text('${formatTaka(223600)}  ${formatTaka(62049)}', style: AppType.amount56),
            Text('title24 ৳1,622', style: AppType.title24),
            Text('heading20 ৳1,422', style: AppType.heading20),
            Text('body16 ৳200', style: AppType.body16),
          ],
        ),
      ),
    );
  }
}
