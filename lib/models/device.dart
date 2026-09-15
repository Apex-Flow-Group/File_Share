class Device {
  final String id;
  final String name;
  final String type;
  // mDNS/HTTP transport (PC + Android fallback)
  final String ip;
  final int port;

  /// اسم الجهاز على الشبكة (hostname) — يُرسل مع UDP broadcast
  final String? hostname;
  // Nearby Connections transport (Android)
  final String? endpointId;
  final DateTime? lastSeen;

  /// هل أعلن هذا الجهاز عن مجلد Share مشترك في آخر UDP broadcast؟
  final bool shareEnabled;

  const Device({
    required this.id,
    required this.name,
    required this.type,
    this.ip = '',
    this.port = 0,
    this.hostname,
    this.endpointId,
    this.lastSeen,
    this.shareEnabled = false,
  });

  bool get isNearby => endpointId != null;
  bool get isMdns => ip.isNotEmpty && port > 0;

  /// يملك مجلد Share مشترك متاح عبر HTTP (desktop + بـ IP ومنفذ + أعلن عنه)
  bool get hasShare => type == 'desktop' && isMdns && shareEnabled;

  Device copyWith({
    String? id,
    String? name,
    String? type,
    String? ip,
    int? port,
    String? hostname,
    bool clearHostname = false,
    String? endpointId,
    bool clearEndpointId = false,
    DateTime? lastSeen,
    bool? shareEnabled,
  }) =>
      Device(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        ip: ip ?? this.ip,
        port: port ?? this.port,
        hostname: clearHostname ? null : (hostname ?? this.hostname),
        endpointId: clearEndpointId ? null : (endpointId ?? this.endpointId),
        lastSeen: lastSeen ?? this.lastSeen,
        shareEnabled: shareEnabled ?? this.shareEnabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'ip': ip,
        'port': port,
        if (hostname != null && hostname!.isNotEmpty) 'hostname': hostname,
        if (shareEnabled) 'share': true,
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        type: json['type'] ?? 'unknown',
        ip: json['ip'] ?? '',
        port: json['port'] ?? 0,
        hostname: json['hostname'] as String?,
        shareEnabled: json['share'] == true,
      );
}
