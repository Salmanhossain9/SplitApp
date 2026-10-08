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

/// A Bangladesh mobile number as the login sends it: "+8801XXXXXXXXX". Accepts what people type:
/// "1712345678", "01712345678", "+880 1712-345678". Null unless it is a real mobile number
/// (01 then 3 to 9 and eight more digits).
String? bdMobileE164(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('880')) digits = digits.substring(3);
  if (digits.startsWith('0')) digits = digits.substring(1);
  return RegExp(r'^1[3-9]\d{8}$').hasMatch(digits) ? '+880$digits' : null;
}
