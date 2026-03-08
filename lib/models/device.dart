import '../core/apex_constants.dart';

class Device {
  final String id;
  final String name;
  final String ip;
  final String type;
  final int port;
  final DateTime? lastSeen;

  Device({
    required this.id,
    required this.name,
    required this.ip,
    required this.type,
    this.port = ApexConstants.transferPort,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Device copyWith({
    String? id,
    String? name,
    String? ip,
    String? type,
    int? port,
    DateTime? lastSeen,
  }) => Device(
    id: id ?? this.id,
    name: name ?? this.name,
    ip: ip ?? this.ip,
    type: type ?? this.type,
    port: port ?? this.port,
    lastSeen: lastSeen ?? this.lastSeen,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'type': type,
    'port': port,
  };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'],
    name: json['name'],
    ip: json['ip'],
    type: json['type'],
    port: json['port'] ?? ApexConstants.transferPort,
  );
}
