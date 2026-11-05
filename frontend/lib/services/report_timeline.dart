DateTime previousReportMonth(DateTime now) => DateTime(now.year, now.month - 1);

class ReportFlowPoint {
  final DateTime date;
  final Map<String, int> cents = {};
  int availableCents = 0;

  ReportFlowPoint(this.date);

  double amount(String type) => (cents[type] ?? 0) / 100;
  double get available => availableCents / 100;
}

class ReportTimeline {
  final bool monthly;
  final List<ReportFlowPoint> points;

  ReportTimeline._(this.monthly, this.points);

  factory ReportTimeline.build({
    required Iterable<({DateTime date, String type, double amount})>
    transactions,
    required DateTime start,
    required DateTime end,
  }) {
    if (!end.isAfter(start)) throw ArgumentError('Invalid report period');
    final first = DateTime(start.year, start.month, start.day);
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
    final monthly = days > 62;
    final points = <ReportFlowPoint>[];
    final byDate = <DateTime, ReportFlowPoint>{};
    var date = monthly ? DateTime(first.year, first.month) : first;
    while (date.isBefore(end)) {
      final point = ReportFlowPoint(date);
      points.add(point);
      byDate[date] = point;
      date = monthly
          ? DateTime(date.year, date.month + 1)
          : DateTime(date.year, date.month, date.day + 1);
    }
    for (final tx in transactions) {
      if (tx.date.isBefore(start) || !tx.date.isBefore(end)) continue;
      final key = DateTime(
        tx.date.year,
        tx.date.month,
        monthly ? 1 : tx.date.day,
      );
      final point = byDate[key];
      if (point == null) continue;
      final cents = (tx.amount.abs() * 100).round();
      point.cents.update(tx.type, (v) => v + cents, ifAbsent: () => cents);
    }
    var available = 0;
    for (final point in points) {
      available +=
          (point.cents['income'] ?? 0) -
          (point.cents['expense'] ?? 0) -
          (point.cents['investment'] ?? 0);
      point.availableCents = available;
    }
    return ReportTimeline._(monthly, points);
  }
}
