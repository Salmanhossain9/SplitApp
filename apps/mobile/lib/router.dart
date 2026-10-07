import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'features/bill/charges_screen.dart';
import 'features/bill/claim_screen.dart';
import 'features/bill/items_screen.dart';
import 'features/bill/new_bill_screen.dart';
import 'features/bill/settle_screen.dart';
import 'features/gallery/gallery_screen.dart';
import 'features/home/home_screen.dart';
import 'features/welcome/welcome_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/bill/new', builder: (_, _) => const NewBillScreen()),
    GoRoute(path: '/bill/:id/items', builder: (_, _) => const ItemsScreen()),
    GoRoute(path: '/bill/:id/claim', builder: (_, _) => const ClaimScreen()),
    GoRoute(path: '/bill/:id/charges', builder: (_, _) => const ChargesScreen()),
    GoRoute(path: '/bill/:id/settle', builder: (_, _) => const SettleScreen()),
    if (kDebugMode) GoRoute(path: '/gallery', builder: (_, _) => const GalleryScreen()),
  ],
);
