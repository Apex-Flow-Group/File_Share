import 'package:apex_file_share/core/discovery_merge.dart';
import 'package:apex_file_share/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

Device _lan(String id, String name, String ip, int port) =>
    Device(id: id, name: name, type: 'desktop', ip: ip, port: port);

Device _nearby(String endpoint, String name) =>
    Device(id: endpoint, name: name, type: 'phone', endpointId: endpoint);

void main() {
  test('a device that restarted on a new port is reached on the new one', () {
    final known = <String, Device>{};
    mergeFound(known, _lan('pc', 'Office PC', '192.168.8.97', 64634));
    mergeFound(known, _lan('pc', 'Office PC', '192.168.8.97', 60363));
    expect(known.values.single.port, 60363,
        reason: 'the old port answered nothing, and its packets kept it listed');
  });

  test('a new address from the router replaces the old one', () {
    final known = <String, Device>{};
    mergeFound(known, _lan('pc', 'Office PC', '192.168.8.97', 4000));
    mergeFound(known, _lan('pc', 'Office PC', '192.168.8.120', 4000));
    expect(known.values.single.ip, '192.168.8.120');
  });

  test('two devices with one name stay two', () {
    final known = <String, Device>{};
    mergeFound(known, _lan('a', 'Laptop', '192.168.8.10', 4000));
    mergeFound(known, _lan('b', 'Laptop', '192.168.8.11', 4000));
    expect(known.keys, unorderedEquals(['a', 'b']));
    expect(known['a']!.ip, '192.168.8.10', reason: 'one must not take the other address');
  });

  test('Nearby and the network of one phone are one record, merged by name', () {
    final known = <String, Device>{};
    mergeFound(known, _lan('phone', 'Ali Phone', '192.168.8.84', 4000));
    mergeFound(known, _nearby('ep1', 'Ali Phone'));
    expect(known.values.single.endpointId, 'ep1');
    expect(known.values.single.ip, '192.168.8.84');

    final other = <String, Device>{};
    mergeFound(other, _nearby('ep1', 'Ali Phone'));
    mergeFound(other, _lan('phone', 'Ali Phone', '192.168.8.84', 4000));
    expect(other.values.single.endpointId, 'ep1');
    expect(other.values.single.port, 4000);
  });

  test('a network refresh keeps the Nearby link of a merged phone', () {
    final known = <String, Device>{};
    mergeFound(known, _lan('phone', 'Ali Phone', '192.168.8.84', 4000));
    mergeFound(known, _nearby('ep1', 'Ali Phone'));
    mergeFound(known, _lan('phone', 'Ali Phone', '192.168.8.84', 4001));
    expect(known.values.single.endpointId, 'ep1');
    expect(known.values.single.port, 4001);
  });
}
