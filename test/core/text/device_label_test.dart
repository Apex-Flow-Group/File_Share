import 'package:apex_file_share/core/text/device_label.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner decision (2026-11-03): a Fedora PC with no static hostname got
/// "58-11-22-A8-AB-8E" from the network and showed under that name. A name
/// that looks like a MAC address is replaced by "<user> · <system>"; a name
/// the user typed stays as it is.
void main() {
  group('looks like a MAC address', () {
    for (final name in ['58-11-22-A8-AB-8E', '58:11:22:a8:ab:8e', '581122A8AB8E']) {
      test(name, () => expect(looksLikeMac(name), isTrue));
    }
    for (final name in ['DESKTOP-K2VD857', 'fedora', 'jawal-pc', 'Jawal 2026', '58-11-22']) {
      test('not $name', () => expect(looksLikeMac(name), isFalse));
    }
  });

  group('the name a desktop shows', () {
    test('a real hostname is kept', () {
      expect(desktopName('jawal-pc', user: 'jawal', system: 'Fedora Linux'), 'jawal-pc');
    });

    test('a MAC-like hostname becomes user, system and its last 4 characters', () {
      expect(desktopName('58-11-22-A8-AB-8E', user: 'jawal', system: 'Fedora Linux'),
          'jawal · Fedora · AB8E');
      expect(desktopName('58:11:22:a8:ab:8e', user: 'jawal', system: 'Fedora Linux'),
          'jawal · Fedora · AB8E');
    });

    test('two PCs of the same user and system still differ', () {
      expect(desktopName('58-11-22-A8-AB-8E', user: 'jawal', system: 'Fedora Linux'),
          isNot(desktopName('58-11-22-A8-C3-10', user: 'jawal', system: 'Fedora Linux')));
    });

    test('with no user name, the system and the 4 characters', () {
      expect(desktopName('58-11-22-A8-AB-8E', user: '', system: 'Fedora Linux'), 'Fedora · AB8E');
    });

    test('with no hostname at all, Linux', () {
      expect(desktopName('', user: '', system: ''), 'Linux');
    });
  });

  group('the saved name', () {
    test('a name the user typed is kept', () {
      expect(savedNameStillValid('My Office PC'), isTrue);
    });

    test('a MAC-like name saved automatically by an older run is replaced', () {
      expect(savedNameStillValid('58-11-22-A8-AB-8E'), isFalse);
    });
  });
}
