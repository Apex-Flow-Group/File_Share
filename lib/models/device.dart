class Device {
  final String id;
  final String name;
  final String type;
  // mDNS/HTTP transport (PC + Android fallback)
  final String ip;
  final int port;
  // Nearby Connections transport (Android)
  final String? endpointId;
  final DateTime? lastSeen;

  const Device({
    required this.id,
    required this.name,
    required this.type,
    this.ip = '',
    this.port = 0,
    this.endpointId,
    this.lastSeen,
  });

  bool get isNearby => endpointId != null;
  bool get isMdns => ip.isNotEmpty && port > 0;

  Device copyWith({
    String? id,
    String? name,
    String? type,
    String? ip,
    int? port,
    String? endpointId,
    DateTime? lastSeen,
  }) =>
      Device(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        ip: ip ?? this.ip,
        port: port ?? this.port,
        endpointId: endpointId ?? this.endpointId,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'ip': ip,
        'port': port,
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        type: json['type'] ?? 'unknown',
        ip: json['ip'] ?? '',
        port: json['port'] ?? 0,
      );
}
