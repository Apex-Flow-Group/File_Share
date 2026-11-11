/// A Linux PC with no static hostname gets one from the network built from its
/// MAC address ("58-11-22-A8-AB-8E"), which tells the user nothing.
bool looksLikeMac(String name) =>
    RegExp(r'^[0-9A-Fa-f]{2}([-:]?)[0-9A-Fa-f]{2}(\1[0-9A-Fa-f]{2}){4}$').hasMatch(name.trim());

/// The hostname, unless it is empty or MAC-like: then "<user> · <system>",
/// plus the last 4 characters of a MAC-like name so two PCs of the same user
/// and system still differ.
String desktopName(String hostname, {required String user, required String system}) {
  final host = hostname.trim();
  if (host.isNotEmpty && !looksLikeMac(host)) {
    return host;
  }
  var os = system.trim();
  if (os.endsWith(' Linux')) {
    os = os.substring(0, os.length - ' Linux'.length).trim();
  }
  if (os.isEmpty) {
    os = 'Linux';
  }
  final hex = host.replaceAll(RegExp('[-:]'), '').toUpperCase();
  final parts = [
    if (user.trim().isNotEmpty) user.trim(),
    os,
    if (hex.length >= 4) hex.substring(hex.length - 4),
  ];
  return parts.join(' · ');
}

/// Older runs saved the hostname automatically, so a MAC-like saved name was
/// never typed by the user and is replaced.
bool savedNameStillValid(String saved) => saved.trim().isNotEmpty && !looksLikeMac(saved);
