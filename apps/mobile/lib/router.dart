import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'features/gallery/gallery_screen.dart';
import 'features/welcome/welcome_screen.dart';

final appRouter = GoRouter(
  initialLocation: kDebugMode ? '/gallery' : '/welcome',
  routes: [
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    if (kDebugMode) GoRoute(path: '/gallery', builder: (_, _) => const GalleryScreen()),
  ],
);
