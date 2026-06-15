/// A room within the user's home. Cloud-owned soft metadata a device can be
/// assigned to (device-model-v2). `id` is the stable cloud room id; `name` is
/// the user-facing label.
class Room {
  const Room({required this.id, required this.name});

  final String id;
  final String name;
}
