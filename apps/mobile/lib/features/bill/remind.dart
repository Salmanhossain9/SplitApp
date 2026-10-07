import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../share/share_service.dart';
import 'bill_repository.dart';
import 'bill_summary.dart';
import 'bills_provider.dart';

/// The `remind` pill. App users get a push (or at least an in-app notification); guests get a
/// WhatsApp message to send themselves. One reminder per tab per 24 hours.
Future<void> remindFriend(BuildContext context, WidgetRef ref, OpenTab tab) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text, {bool bad = false}) => messenger.showSnackBar(SnackBar(
        backgroundColor: bad ? AppColors.coral : AppColors.navy,
        content: Text(text, style: AppType.body16.copyWith(color: AppColors.white)),
      ));

  final outcome = await ref.read(billRepositoryProvider).remind(tab);
  switch (outcome) {
    case RemindSent():
      say('reminder sent to ${tab.personName}.');
    case RemindWhatsapp(:final link):
      final opened = await ref.read(shareServiceProvider).openUrl(link);
      if (!opened) say('could not open WhatsApp.', bad: true);
    case RemindTooSoon(:final hours):
      say('you already nudged ${tab.personName}. try again in ${hours}h.');
    case RemindFailed(:final message):
      say(message, bad: true);
  }
}
