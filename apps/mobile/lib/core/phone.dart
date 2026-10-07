/// A WhatsApp-ready number for Bangladesh: digits only, local "01..." becomes "8801...".
/// Mirrors `whatsappLink` in the send-reminders edge function. Null when it is too short.
String? whatsappDigits(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = '880${digits.substring(1)}';
  return digits.length < 10 ? null : digits;
}

Uri? whatsappChatUri(String phone, String text) {
  final digits = whatsappDigits(phone);
  return digits == null ? null : Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
}
