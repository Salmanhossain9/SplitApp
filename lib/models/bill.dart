class Bill {
  const Bill({
    required this.place,
    required this.peopleCount,
    required this.dateLabel,
    required this.totalPoisha,
    required this.isSettled,
  });

  final String place;
  final int peopleCount;
  final String dateLabel;
  final int totalPoisha;
  final bool isSettled;
}