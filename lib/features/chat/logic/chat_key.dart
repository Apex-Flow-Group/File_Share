import '../../../models/device.dart';
import '../../identity/fingerprint.dart';

/// Whom a chat, its unread count, its token and its quiet period belong to:
/// the fingerprint of the device's certificate (owner decision). The same
/// device at a new address keeps its chat; a new device at an old address,
/// or one announcing a colleague's id with its own key, gets an empty one.
final class ChatKey {
  const ChatKey(this.fingerprint);

  /// A device that showed no certificate (Nearby, another version, a
  /// favorite never accepted): only what the user wrote to it, which never
  /// reaches it, so it is kept apart from every other such device.
  ChatKey.unverified(String id, String address) : fingerprint = 'unverified:$id@$address';

  final String fingerprint;

  @override
  bool operator ==(Object other) => other is ChatKey && other.fingerprint == fingerprint;

  @override
  int get hashCode => fingerprint.hashCode;

  @override
  String toString() => 'ChatKey($fingerprint)';
}

/// The device at the other end as it announced itself this time. Its key
/// picks the chat; a block holds its key and its id (owner decision), so a
/// blocked device that comes back with a new key is still blocked.
typedef ChatPeer = ({ChatKey key, String id, String address});

ChatPeer chatPeer(String fingerprint, String id, String address) =>
    (key: ChatKey(fingerprint), id: id, address: address);

extension DeviceChatKey on Device {
  ChatKey get chatKey => isFingerprint(fingerprint) ? ChatKey(fingerprint) : ChatKey.unverified(id, ip);

  ChatPeer get chatPeer => (key: chatKey, id: id, address: ip);
}

/// What a block holds. One entry matches a device by either half.
typedef ChatBlock = ({ChatKey key, String id});

bool blocks(ChatBlock b, ChatPeer p) => b.key == p.key || b.id == p.id;
