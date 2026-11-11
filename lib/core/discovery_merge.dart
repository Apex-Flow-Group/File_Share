import '../models/device.dart';

/// Puts a found [device] into [known], keyed as the list keeps it.
///
/// A network device is the same one only by its id: its new port or address
/// (it restarted, or the router gave another) replaces the old one, which
/// would otherwise stay reachable nowhere while its packets kept it fresh.
/// And two devices with one name stay two. Only a Nearby record and a
/// network record merge by name, since Nearby gives no id of the app.
void mergeFound(Map<String, Device> known, Device device) {
  String? sameName(bool Function(Device) kind) => known.entries
      .where((e) => kind(e.value) && e.value.name.toLowerCase() == device.name.toLowerCase())
      .map((e) => e.key)
      .firstOrNull;

  if (device.isNearby) {
    final key = known.containsKey(device.id) ? null : sameName((d) => d.isMdns && !d.isNearby);
    if (key != null) {
      known[key] = known[key]!.copyWith(endpointId: device.endpointId, lastSeen: device.lastSeen);
    } else {
      known[device.id] = device;
    }
    return;
  }

  final mine = known[device.id];
  if (mine != null) {
    known[device.id] = device.copyWith(endpointId: mine.endpointId);
    return;
  }
  final nearbyOnly = sameName((d) => d.isNearby && !d.isMdns);
  if (nearbyOnly != null) {
    known[nearbyOnly] = known[nearbyOnly]!.copyWith(
      ip: device.ip,
      port: device.port,
      shareEnabled: device.shareEnabled,
      lastSeen: device.lastSeen,
      fingerprint: device.fingerprint,
      certificate: device.certificate,
    );
    return;
  }
  known[device.id] = device;
}
