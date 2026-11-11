import '../../../models/device.dart';

/// Whom a chat, its unread count, its token and its block belong to: the id
/// a device announces together with its real address. The address alone is
/// not enough: the router gives a device's address to another one, which
/// would then see its chat and inherit its block.
typedef ChatKey = ({String id, String address});

ChatKey chatKey(String id, String address) => (id: id, address: address);

extension DeviceChatKey on Device {
  ChatKey get chatKey => (id: id, address: ip);
}
