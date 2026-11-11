// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Apex Transfer';

  @override
  String get send => 'Send';

  @override
  String get receive => 'My Device';

  @override
  String get files => 'Files';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get support => 'Support';

  @override
  String get home => 'Home';

  @override
  String get thisDevice => 'This Device';

  @override
  String get deviceName => 'Device Name';

  @override
  String get deviceType => 'Device Type';

  @override
  String get status => 'Status';

  @override
  String get ipAddress => 'IP Address';

  @override
  String get hostname => 'Computer Name';

  @override
  String get hostnamePhone => 'Phone Model';

  @override
  String get hostnameTablet => 'Tablet Model';

  @override
  String get hostnameTv => 'TV Model';

  @override
  String get editDeviceName => 'Edit Device Name';

  @override
  String get deviceNameUpdated => 'Device name updated';

  @override
  String get device => 'Device';

  @override
  String get discovering => 'Discovering...';

  @override
  String get idle => 'Idle';

  @override
  String get unknown => 'Unknown';

  @override
  String get unknownDevice => 'Unknown Device';

  @override
  String get phone => 'Phone';

  @override
  String get tablet => 'Tablet';

  @override
  String get desktop => 'Desktop';

  @override
  String get noDevicesFound => 'No devices found';

  @override
  String get makeSureDevicesOnSameNetwork =>
      'Make sure devices are on the same network';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connected => 'Connected';

  @override
  String get tapToConnect => 'Tap to connect';

  @override
  String get sendFile => 'Send File';

  @override
  String get selectDevice => 'Select Device';

  @override
  String get cancel => 'Cancel';

  @override
  String get filePickError => 'File pick error';

  @override
  String get sendingFileTo => 'Sending file to';

  @override
  String get noDevicesConnected => 'No devices connected';

  @override
  String get howToReceive => 'How to Receive';

  @override
  String get instruction1 =>
      'Make sure all devices are connected to the same WiFi network';

  @override
  String get instruction2 => 'Open the app on other devices';

  @override
  String get instruction3 => 'Devices will be discovered automatically';

  @override
  String get instruction4 => 'Wait to receive files from other devices';

  @override
  String get startDiscovery => 'Start Discovery';

  @override
  String get stopDiscovery => 'Stop Discovery';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get connectionError => 'Connection error';

  @override
  String get deleteFiles => 'Delete Files';

  @override
  String get noFiles => 'No files';

  @override
  String get noFilesHint => 'Received files will appear here';

  @override
  String get openFolder => 'Open Folder';

  @override
  String get openFile => 'Open File';

  @override
  String get selected => 'selected';

  @override
  String get sortBy => 'Sort by';

  @override
  String get date => 'Date';

  @override
  String get size => 'Size';

  @override
  String get type => 'Type';

  @override
  String get name => 'Name';

  @override
  String get save => 'Save';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get permissions => 'Permissions';

  @override
  String get appPermissions => 'App Permissions';

  @override
  String get managePermissions => 'Manage Permissions';

  @override
  String get systemSettings => 'System Settings';

  @override
  String get openSystemSettings => 'Open System Settings';

  @override
  String get network => 'Network';

  @override
  String get wifiDirect => 'WiFi Direct';

  @override
  String get wifiDirectDesc => 'Direct connection between devices';

  @override
  String get localNetwork => 'Local Network';

  @override
  String get localNetworkDesc => 'Discover devices on same network';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get location => 'Location';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get storageLabel => 'Storage';

  @override
  String get nearbyDevices => 'Nearby Devices';

  @override
  String get close => 'Close';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get notConnected => 'Not Connected';

  @override
  String get defaultDevice => 'Device';

  @override
  String get sendFailed => 'Send failed';

  @override
  String get accept => 'Accept';

  @override
  String get reject => 'Reject';

  @override
  String get selectAll => 'Select All';

  @override
  String get deleteConfirmation => 'Do you want to delete';

  @override
  String get delete => 'Delete';

  @override
  String get sortPreferenceSaved => 'Sort preferences saved';

  @override
  String get connectionRequest => 'Connection Request';

  @override
  String get deviceWantsToConnect => 'Device wants to connect:';

  @override
  String get acceptConnection => 'Do you want to accept the connection?';

  @override
  String get incomingFilesTitle => 'Incoming files';

  @override
  String get shareAccessTitle => 'Shared folder request';

  @override
  String get shareAccessDownload =>
      'Let this device download files from your shared folder?';

  @override
  String get shareAccessDownloadUpload =>
      'Let this device download files from your shared folder and upload to it?';

  @override
  String receiveFilesQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Receive $count files?',
      one: 'Receive 1 file?',
    );
    return '$_temp0';
  }

  @override
  String get ok => 'OK';

  @override
  String get reconnectFailed => 'Reconnect failed';

  @override
  String get restartingSystem => 'Refresh';

  @override
  String get sendApp => 'Send App';

  @override
  String get sendFolder => 'Send Folder';

  @override
  String get sendThisFolder => 'Send this folder';

  @override
  String get pickFolder => 'Choose a folder';

  @override
  String get folderSent => 'Folder sent';

  @override
  String get compressingFolder => 'Compressing folder…';

  @override
  String get installedApps => 'Installed Apps';

  @override
  String get noApps => 'No apps';

  @override
  String get systemApps => 'Show system apps';

  @override
  String sendCount(int count) {
    return 'Send ($count)';
  }

  @override
  String get pinDevice => 'Add to favorites';

  @override
  String get unpinDevice => 'Remove from favorites';

  @override
  String get deviceOffline => 'Currently offline';

  @override
  String get pickApp => 'Choose an app';

  @override
  String get directConnection => 'Nearby';

  @override
  String get appSent => 'App sent';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get finish => 'Get Started';

  @override
  String get textCopied => 'Text copied';

  @override
  String get systemStartFailed => 'System start failed';

  @override
  String get fileReceived => 'File received';

  @override
  String filesReceivedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files received',
      one: 'File received',
    );
    return '$_temp0';
  }

  @override
  String get openFiles => 'Show Files';

  @override
  String get openFileFailed => 'Couldn\'t open the file.';

  @override
  String get openLocationFailed => 'Couldn\'t open the folder.';

  @override
  String get folderMissing => 'The folder was deleted or moved.';

  @override
  String get filesDeletedCount => 'files deleted';

  @override
  String get fileSentSuccess => 'File sent successfully';

  @override
  String get fileSendFailed => 'Failed to send file';

  @override
  String get from => 'From';

  @override
  String get savedIn => 'Saved in';

  @override
  String get receiving => 'Receiving...';

  @override
  String get fileSize => 'File Size';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get yourName => 'Name';

  @override
  String get email => 'Email';

  @override
  String get subject => 'Subject';

  @override
  String get message => 'Message';

  @override
  String get sending => 'Sending…';

  @override
  String get sendMessage => 'Send';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get emailOpened => 'Email app opened';

  @override
  String get inquiry => 'Inquiry';

  @override
  String get technicalIssue => 'Technical Issue';

  @override
  String get suggestion => 'Suggestion';

  @override
  String get other => 'Other';

  @override
  String get aboutApp => 'About App';

  @override
  String get appDescription => 'Fast and secure file sharing app';

  @override
  String get importantLinks => 'Important Links';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get legalInfo => 'Legal Information';

  @override
  String get disclaimer => 'Disclaimer';

  @override
  String get disclaimerText =>
      'This app is provided \"as is\" without any warranties. Apex Flow Group is not responsible for any losses or damages resulting from the use of the app.';

  @override
  String get copyright => 'Copyright';

  @override
  String get copyrightText => '© 2025 Apex Flow Group. All rights reserved.';

  @override
  String get madeInArabWorld => 'Made in the Arab World';

  @override
  String get availableDevices => 'Available Devices';

  @override
  String get systemNotRunning => 'System not running';

  @override
  String foundSongs(int count) {
    return 'Found $count songs';
  }

  @override
  String get fastAndSecure => 'Fast, Secure & Offline';

  @override
  String get startTour => 'Start Tour';

  @override
  String get feature1Title => 'Fast Transfer';

  @override
  String get feature1Desc => 'Send files at high speed via WiFi';

  @override
  String get feature2Title => 'No Internet';

  @override
  String get feature2Desc => 'Works on local network only';

  @override
  String get feature3Title => 'Secure & Encrypted';

  @override
  String get feature3Desc => 'Full protection for your files';

  @override
  String get notConnectedToWiFi => 'Not Connected to WiFi';

  @override
  String get mustConnectToWiFi =>
      'You must connect to a WiFi network to use the app';

  @override
  String get openWiFiSettings => 'Open WiFi Settings';

  @override
  String get createHotspot => 'Create Hotspot';

  @override
  String get exitApp => 'Exit App';

  @override
  String get exitConfirmation => 'Do you want to exit the app?';

  @override
  String get exit => 'Exit';

  @override
  String get pressMenuForSettings => 'Press MENU for Settings';

  @override
  String get category => 'Category';

  @override
  String get weAreHappyToHear => 'We are happy to hear from you';

  @override
  String get deleteFromFolders => 'Delete from folders too';

  @override
  String get permanentDeleteWarning =>
      'Files will be permanently deleted from storage';

  @override
  String get deleteFromListOnly => 'Files will be removed from list only';

  @override
  String get cannotUndoWarning => 'Warning: This action cannot be undone';

  @override
  String get deletePermanent => 'Delete Permanently';

  @override
  String get deleteWarning => 'Files will be permanently deleted!';

  @override
  String get filesCount => 'Files Count';

  @override
  String get fileSentSuccessfully => 'File sent successfully';

  @override
  String get pickFile => 'Choose a file';

  @override
  String get clipboardSend => 'Send';

  @override
  String get clipboardTypeImage => 'Image';

  @override
  String get clipboardTypeText => 'Text';

  @override
  String get clipboardSendTooltip => 'Send from clipboard';

  @override
  String get clipboardSettings => 'Clipboard';

  @override
  String get watchClipboard => 'Offer to send what you copy';

  @override
  String get watchClipboardDesc =>
      'Each time you copy, a button to send what you copied appears on the connected device cards in the Send tab. It reads everything you copy, passwords included.';

  @override
  String get pinnedDevices => 'Favorite Devices';

  @override
  String get newDevices => 'New Devices';

  @override
  String get sharedFolder => 'Shared Folder';

  @override
  String get uploadToSharedFolder => 'Upload to Shared Folder';

  @override
  String get sharedFolderEmpty => 'Shared folder is empty';

  @override
  String get sharedFolderEmptyHint =>
      'Drop files here or use the upload button';

  @override
  String get sharedFolderDisabled => 'Shared folder is disabled';

  @override
  String get allowShareUploads => 'Allow uploads';

  @override
  String get allowShareUploadsDesc =>
      'Allow other devices to upload files to this folder';

  @override
  String get enableSharedFolder => 'Enable Shared Folder';

  @override
  String get enableSharedFolderDesc =>
      'Share a folder on the network with nearby devices';

  @override
  String get downloadFromShare => 'Download';

  @override
  String get uploadSuccess => 'File uploaded successfully';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String downloadSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String shareFileCount(int count) {
    return '$count file(s)';
  }

  @override
  String get browseSharedFolder => 'Browse Shared Folder';

  @override
  String get deletedFromShare => 'File deleted';

  @override
  String get confirmDeleteFromShare =>
      'Delete this file from the shared folder?';

  @override
  String get shareNetworkError => 'Device unreachable';

  @override
  String get shareAccessRefused =>
      'The owner of the other device refused to open their shared folder';

  @override
  String get shareNoAnswer => 'The owner of the other device did not answer';

  @override
  String get shareOffRemote =>
      'The shared folder is not enabled on the other device';

  @override
  String get retry => 'Try again';

  @override
  String get updateRequired =>
      'The app version differs between the two devices. Update it on both';

  @override
  String get versionDiffers => 'Different app version';

  @override
  String get uploading => 'Uploading...';

  @override
  String get downloading => 'Downloading...';

  @override
  String get sendDeclined => 'The other device declined';

  @override
  String get sendNoAnswer => 'The other device did not answer';

  @override
  String get sendReceiverBusy =>
      'The other device is answering another request. Try again shortly';

  @override
  String get sendCancelled => 'Sending was cancelled';

  @override
  String sendTooManyFiles(int max) {
    return 'You can send at most $max files at a time';
  }

  @override
  String get sendNoSpace => 'Not enough space on the other device';

  @override
  String clipboardTextLength(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Text ($count characters)',
      one: 'Text (1 character)',
    );
    return '$_temp0';
  }

  @override
  String clipboardCharCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters',
      one: '1 character',
    );
    return '$_temp0';
  }

  @override
  String clipboardFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get chatOpen => 'Chat';

  @override
  String get chatRequestTitle => 'Chat request';

  @override
  String get chatRequestQuestion => 'Accept chat?';

  @override
  String get chatHint => 'Write a message';

  @override
  String get chatEmpty => 'No messages yet';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatMessages => 'Messages';

  @override
  String get chatDeclined => 'The other device declined the chat';

  @override
  String get chatFailed => 'The message did not arrive';

  @override
  String chatNewMessage(String name) {
    return 'Message from $name';
  }

  @override
  String chatTooLong(int max) {
    return 'The message is longer than $max characters';
  }
}
