/// Reported presence/occupancy for a motion sensor.
///
/// The cloud surfaces this as `state.occupancy` on the per-device state
/// endpoint and emits `"occupied"` / `"unoccupied"` literals; anything else
/// (including a missing field) maps to [unknown] so the UI can render a
/// neutral "no data yet" state without guessing.
enum OccupancyState {
  occupied,
  unoccupied,
  unknown;

  static OccupancyState fromJson(Object? value) {
    return switch (value) {
      'occupied' => OccupancyState.occupied,
      'unoccupied' => OccupancyState.unoccupied,
      _ => OccupancyState.unknown,
    };
  }
}
