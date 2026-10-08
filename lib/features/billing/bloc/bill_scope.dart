/// Which bills the Billing page shows: one year or every year ([year] null), and any bills or only a tenant's or a
/// room's.
class BillView {
  final int? year;
  final int? tenantId;
  final int? roomId;

  const BillView({this.year, this.tenantId, this.roomId});

  @override
  bool operator ==(Object other) => other is BillView && other.year == year && other.tenantId == tenantId && other.roomId == roomId;

  @override
  int get hashCode => Object.hash(year, tenantId, roomId);

  @override
  String toString() => 'BillView(year: $year, tenant: $tenantId, room: $roomId)';
}

/// Which bills the app has loaded: every bill created on or after [since] plus every bill without a receipt (the
/// first load, enough for the dashboard, Verify and this year's Billing page), and since then whole years, tenants
/// and rooms, or [all] bills.
class BillCoverage {
  /// The day the first load starts from (sent as `since=YYYY-MM-DD`; the server compares UTC times).
  final DateTime since;
  final bool all;
  final Set<int> years;
  final Set<int> tenants;
  final Set<int> rooms;

  const BillCoverage({required this.since, this.all = false, this.years = const {}, this.tenants = const {}, this.rooms = const {}});

  /// The first load's start for [now]: the 1st of the month 11 months back (twelve months with this one), a day
  /// earlier so bills of that 1st in local time (ahead of UTC) are in.
  static DateTime sinceFor(DateTime now) => DateTime(now.year, now.month - 11, 1).subtract(const Duration(days: 1));

  /// Whether every bill [view] can show is loaded.
  bool covers(BillView view) {
    if (all) return true;
    final year = view.year;
    // A year starting (in local time) after [since] came with the first load.
    if (year != null && (years.contains(year) || !DateTime(year - 1, 12, 31).isBefore(since))) return true;
    if (view.tenantId case final tenant? when tenants.contains(tenant)) return true;
    if (view.roomId case final room? when rooms.contains(room)) return true;
    return false;
  }

  /// What a [view] fetch adds (see [BillQuery.of]).
  BillCoverage including(BillView view) => switch (BillQuery.of(view)) {
    BillQuery(:final year?) => _copy(years: {...years, year}),
    BillQuery(:final tenantId?) => _copy(tenants: {...tenants, tenantId}),
    BillQuery(:final roomId?) => _copy(rooms: {...rooms, roomId}),
    _ => _copy(all: true),
  };

  BillCoverage _copy({bool? all, Set<int>? years, Set<int>? tenants, Set<int>? rooms}) =>
      BillCoverage(since: since, all: all ?? this.all, years: years ?? this.years, tenants: tenants ?? this.tenants, rooms: rooms ?? this.rooms);
}

/// The one filter a fetch for a [BillView] sends (the page filters the rest itself): the year if there is one, else
/// the tenant, else the room, else none (every bill).
class BillQuery {
  final int? year;
  final int? tenantId;
  final int? roomId;

  const BillQuery({this.year, this.tenantId, this.roomId});

  factory BillQuery.of(BillView view) => switch (view) {
    BillView(:final year?) => BillQuery(year: year),
    BillView(:final tenantId?) => BillQuery(tenantId: tenantId),
    BillView(:final roomId?) => BillQuery(roomId: roomId),
    _ => const BillQuery(),
  };
}
