import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now", injectable so greetings, month headers and reminders can be tested.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
