import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'Apex Transfer'**
  String get appTitle;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'My Device'**
  String get receive;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This Device'**
  String get thisDevice;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceName;

  /// No description provided for @deviceType.
  ///
  /// In en, this message translates to:
  /// **'Device Type'**
  String get deviceType;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @ipAddress.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get ipAddress;

  /// No description provided for @hostname.
  ///
  /// In en, this message translates to:
  /// **'Computer Name'**
  String get hostname;

  /// No description provided for @hostnamePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Model'**
  String get hostnamePhone;

  /// No description provided for @hostnameTablet.
  ///
  /// In en, this message translates to:
  /// **'Tablet Model'**
  String get hostnameTablet;

  /// No description provided for @hostnameTv.
  ///
  /// In en, this message translates to:
  /// **'TV Model'**
  String get hostnameTv;

  /// No description provided for @editDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Edit Device Name'**
  String get editDeviceName;

  /// No description provided for @deviceNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Device name updated'**
  String get deviceNameUpdated;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get device;

  /// No description provided for @discovering.
  ///
  /// In en, this message translates to:
  /// **'Searching for devices…'**
  String get discovering;

  /// No description provided for @availableDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No devices available} =1{1 device available} other{{count} devices available}}'**
  String availableDeviceCount(int count);

  /// No description provided for @fileCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No files} =1{1 file} other{{count} files}}'**
  String fileCount(int count);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @loadingApps.
  ///
  /// In en, this message translates to:
  /// **'Loading apps…'**
  String get loadingApps;

  /// No description provided for @reloadFiles.
  ///
  /// In en, this message translates to:
  /// **'Reload files'**
  String get reloadFiles;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknownDevice;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @tablet.
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get tablet;

  /// No description provided for @desktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get desktop;

  /// No description provided for @makeSureDevicesOnSameNetwork.
  ///
  /// In en, this message translates to:
  /// **'Make sure devices are on the same network'**
  String get makeSureDevicesOnSameNetwork;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @tapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to connect'**
  String get tapToConnect;

  /// No description provided for @sendFile.
  ///
  /// In en, this message translates to:
  /// **'Send File'**
  String get sendFile;

  /// No description provided for @selectDevice.
  ///
  /// In en, this message translates to:
  /// **'Select Device'**
  String get selectDevice;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @filePickError.
  ///
  /// In en, this message translates to:
  /// **'File pick error'**
  String get filePickError;

  /// No description provided for @sendingFileTo.
  ///
  /// In en, this message translates to:
  /// **'Sending file to'**
  String get sendingFileTo;

  /// No description provided for @noDevicesConnected.
  ///
  /// In en, this message translates to:
  /// **'No devices connected'**
  String get noDevicesConnected;

  /// No description provided for @howToReceive.
  ///
  /// In en, this message translates to:
  /// **'How to Receive'**
  String get howToReceive;

  /// No description provided for @instruction1.
  ///
  /// In en, this message translates to:
  /// **'Make sure all devices are connected to the same WiFi network'**
  String get instruction1;

  /// No description provided for @instruction2.
  ///
  /// In en, this message translates to:
  /// **'Open the app on other devices'**
  String get instruction2;

  /// No description provided for @instruction3.
  ///
  /// In en, this message translates to:
  /// **'Devices will be discovered automatically'**
  String get instruction3;

  /// No description provided for @instruction4.
  ///
  /// In en, this message translates to:
  /// **'Find received files in \"Files\"'**
  String get instruction4;

  /// No description provided for @readyToReceive.
  ///
  /// In en, this message translates to:
  /// **'Ready to receive files'**
  String get readyToReceive;

  /// No description provided for @startDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Start Discovery'**
  String get startDiscovery;

  /// No description provided for @stopDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Stop Discovery'**
  String get stopDiscovery;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

  /// No description provided for @deleteFiles.
  ///
  /// In en, this message translates to:
  /// **'Delete Files'**
  String get deleteFiles;

  /// No description provided for @noFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get noFiles;

  /// No description provided for @noFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Received files will appear here'**
  String get noFilesHint;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Folder'**
  String get openFolder;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open File'**
  String get openFile;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get selected;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @appPermissions.
  ///
  /// In en, this message translates to:
  /// **'App Permissions'**
  String get appPermissions;

  /// No description provided for @managePermissions.
  ///
  /// In en, this message translates to:
  /// **'Manage Permissions'**
  String get managePermissions;

  /// No description provided for @systemSettings.
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get systemSettings;

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get openSystemSettings;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// No description provided for @wifiDirect.
  ///
  /// In en, this message translates to:
  /// **'WiFi Direct'**
  String get wifiDirect;

  /// No description provided for @wifiDirectDesc.
  ///
  /// In en, this message translates to:
  /// **'Direct connection between devices'**
  String get wifiDirectDesc;

  /// No description provided for @localNetwork.
  ///
  /// In en, this message translates to:
  /// **'Local Network'**
  String get localNetwork;

  /// No description provided for @localNetworkDesc.
  ///
  /// In en, this message translates to:
  /// **'Discover devices on same network'**
  String get localNetworkDesc;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @selectTheme.
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @bluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get bluetooth;

  /// No description provided for @storageLabel.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storageLabel;

  /// No description provided for @nearbyDevices.
  ///
  /// In en, this message translates to:
  /// **'Nearby Devices'**
  String get nearbyDevices;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get notConnected;

  /// No description provided for @defaultDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get defaultDevice;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get sendFailed;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete'**
  String get deleteConfirmation;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @sortPreferenceSaved.
  ///
  /// In en, this message translates to:
  /// **'Sort preferences saved'**
  String get sortPreferenceSaved;

  /// No description provided for @connectionRequest.
  ///
  /// In en, this message translates to:
  /// **'Connection Request'**
  String get connectionRequest;

  /// No description provided for @deviceWantsToConnect.
  ///
  /// In en, this message translates to:
  /// **'Device wants to connect:'**
  String get deviceWantsToConnect;

  /// No description provided for @acceptConnection.
  ///
  /// In en, this message translates to:
  /// **'Do you want to accept the connection?'**
  String get acceptConnection;

  /// No description provided for @incomingFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming files'**
  String get incomingFilesTitle;

  /// No description provided for @shareAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared folder request'**
  String get shareAccessTitle;

  /// No description provided for @shareAccessDownload.
  ///
  /// In en, this message translates to:
  /// **'Let this device download files from your shared folder?'**
  String get shareAccessDownload;

  /// No description provided for @shareAccessDownloadUpload.
  ///
  /// In en, this message translates to:
  /// **'Let this device download files from your shared folder and upload to it?'**
  String get shareAccessDownloadUpload;

  /// No description provided for @receiveFilesQuestion.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Receive 1 file?} other{Receive {count} files?}}'**
  String receiveFilesQuestion(int count);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @reconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Reconnect failed'**
  String get reconnectFailed;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get starting;

  /// No description provided for @sendApp.
  ///
  /// In en, this message translates to:
  /// **'Send App'**
  String get sendApp;

  /// No description provided for @sendFolder.
  ///
  /// In en, this message translates to:
  /// **'Send Folder'**
  String get sendFolder;

  /// No description provided for @sendThisFolder.
  ///
  /// In en, this message translates to:
  /// **'Send this folder'**
  String get sendThisFolder;

  /// No description provided for @pickFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get pickFolder;

  /// No description provided for @folderSent.
  ///
  /// In en, this message translates to:
  /// **'Folder sent'**
  String get folderSent;

  /// No description provided for @compressingFolder.
  ///
  /// In en, this message translates to:
  /// **'Compressing folder…'**
  String get compressingFolder;

  /// No description provided for @installedApps.
  ///
  /// In en, this message translates to:
  /// **'Installed Apps'**
  String get installedApps;

  /// No description provided for @noApps.
  ///
  /// In en, this message translates to:
  /// **'No apps'**
  String get noApps;

  /// No description provided for @systemApps.
  ///
  /// In en, this message translates to:
  /// **'Show system apps'**
  String get systemApps;

  /// No description provided for @sendCount.
  ///
  /// In en, this message translates to:
  /// **'Send ({count})'**
  String sendCount(int count);

  /// No description provided for @pinDevice.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get pinDevice;

  /// No description provided for @unpinDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get unpinDevice;

  /// No description provided for @deviceOffline.
  ///
  /// In en, this message translates to:
  /// **'Currently offline'**
  String get deviceOffline;

  /// No description provided for @pickApp.
  ///
  /// In en, this message translates to:
  /// **'Choose an app'**
  String get pickApp;

  /// No description provided for @directConnection.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get directConnection;

  /// No description provided for @appSent.
  ///
  /// In en, this message translates to:
  /// **'App sent'**
  String get appSent;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get finish;

  /// No description provided for @textCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied'**
  String get textCopied;

  /// No description provided for @fileReceived.
  ///
  /// In en, this message translates to:
  /// **'File received'**
  String get fileReceived;

  /// No description provided for @filesReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{File received} other{{count} files received}}'**
  String filesReceivedTitle(int count);

  /// No description provided for @openFiles.
  ///
  /// In en, this message translates to:
  /// **'Show Files'**
  String get openFiles;

  /// No description provided for @openFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the file.'**
  String get openFileFailed;

  /// No description provided for @openLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the folder.'**
  String get openLocationFailed;

  /// No description provided for @folderMissing.
  ///
  /// In en, this message translates to:
  /// **'The folder was deleted or moved.'**
  String get folderMissing;

  /// No description provided for @fileMissing.
  ///
  /// In en, this message translates to:
  /// **'The file was deleted or moved.'**
  String get fileMissing;

  /// No description provided for @noAppForFile.
  ///
  /// In en, this message translates to:
  /// **'No app can open this type of file.'**
  String get noAppForFile;

  /// No description provided for @filesDeletedCount.
  ///
  /// In en, this message translates to:
  /// **'files deleted'**
  String get filesDeletedCount;

  /// No description provided for @fileSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'File sent successfully'**
  String get fileSentSuccess;

  /// No description provided for @fileSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send file'**
  String get fileSendFailed;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @savedIn.
  ///
  /// In en, this message translates to:
  /// **'Saved in'**
  String get savedIn;

  /// No description provided for @receiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving...'**
  String get receiving;

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'File Size'**
  String get fileSize;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get yourName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendMessage;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @emailOpened.
  ///
  /// In en, this message translates to:
  /// **'Email app opened'**
  String get emailOpened;

  /// No description provided for @inquiry.
  ///
  /// In en, this message translates to:
  /// **'Inquiry'**
  String get inquiry;

  /// No description provided for @technicalIssue.
  ///
  /// In en, this message translates to:
  /// **'Technical Issue'**
  String get technicalIssue;

  /// No description provided for @suggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get suggestion;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutApp;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'Fast and secure file sharing app'**
  String get appDescription;

  /// No description provided for @importantLinks.
  ///
  /// In en, this message translates to:
  /// **'Important Links'**
  String get importantLinks;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @legalInfo.
  ///
  /// In en, this message translates to:
  /// **'Legal Information'**
  String get legalInfo;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get disclaimer;

  /// No description provided for @disclaimerText.
  ///
  /// In en, this message translates to:
  /// **'This app is provided \"as is\" without any warranties. Apex Flow Group is not responsible for any losses or damages resulting from the use of the app.'**
  String get disclaimerText;

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright'**
  String get copyright;

  /// No description provided for @copyrightText.
  ///
  /// In en, this message translates to:
  /// **'© 2025 Apex Flow Group. All rights reserved.'**
  String get copyrightText;

  /// No description provided for @madeInArabWorld.
  ///
  /// In en, this message translates to:
  /// **'Made in the Arab World'**
  String get madeInArabWorld;

  /// No description provided for @startFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start receiving and searching'**
  String get startFailed;

  /// Number of songs found
  ///
  /// In en, this message translates to:
  /// **'Found {count} songs'**
  String foundSongs(int count);

  /// No description provided for @fastAndSecure.
  ///
  /// In en, this message translates to:
  /// **'Fast, Secure & Offline'**
  String get fastAndSecure;

  /// No description provided for @startTour.
  ///
  /// In en, this message translates to:
  /// **'Start Tour'**
  String get startTour;

  /// No description provided for @feature1Title.
  ///
  /// In en, this message translates to:
  /// **'Fast Transfer'**
  String get feature1Title;

  /// No description provided for @feature1Desc.
  ///
  /// In en, this message translates to:
  /// **'Send files at high speed via WiFi'**
  String get feature1Desc;

  /// No description provided for @feature2Title.
  ///
  /// In en, this message translates to:
  /// **'No Internet'**
  String get feature2Title;

  /// No description provided for @feature2Desc.
  ///
  /// In en, this message translates to:
  /// **'Works on local network only'**
  String get feature2Desc;

  /// No description provided for @feature3Title.
  ///
  /// In en, this message translates to:
  /// **'Secure & Encrypted'**
  String get feature3Title;

  /// No description provided for @feature3Desc.
  ///
  /// In en, this message translates to:
  /// **'Full protection for your files'**
  String get feature3Desc;

  /// No description provided for @notConnectedToWiFi.
  ///
  /// In en, this message translates to:
  /// **'Not Connected to WiFi'**
  String get notConnectedToWiFi;

  /// No description provided for @mustConnectToWiFi.
  ///
  /// In en, this message translates to:
  /// **'You must connect to a WiFi network to use the app'**
  String get mustConnectToWiFi;

  /// No description provided for @openWiFiSettings.
  ///
  /// In en, this message translates to:
  /// **'Open WiFi Settings'**
  String get openWiFiSettings;

  /// No description provided for @createHotspot.
  ///
  /// In en, this message translates to:
  /// **'Create Hotspot'**
  String get createHotspot;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exitApp;

  /// No description provided for @exitConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Do you want to exit the app?'**
  String get exitConfirmation;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @pressMenuForSettings.
  ///
  /// In en, this message translates to:
  /// **'Press MENU for Settings'**
  String get pressMenuForSettings;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @weAreHappyToHear.
  ///
  /// In en, this message translates to:
  /// **'We are happy to hear from you'**
  String get weAreHappyToHear;

  /// No description provided for @deleteFromFolders.
  ///
  /// In en, this message translates to:
  /// **'Delete from folders too'**
  String get deleteFromFolders;

  /// No description provided for @permanentDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'Files will be permanently deleted from storage'**
  String get permanentDeleteWarning;

  /// No description provided for @deleteFromListOnly.
  ///
  /// In en, this message translates to:
  /// **'Files will be removed from list only'**
  String get deleteFromListOnly;

  /// No description provided for @cannotUndoWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: This action cannot be undone'**
  String get cannotUndoWarning;

  /// No description provided for @deletePermanent.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get deletePermanent;

  /// No description provided for @deleteWarning.
  ///
  /// In en, this message translates to:
  /// **'Files will be permanently deleted!'**
  String get deleteWarning;

  /// No description provided for @filesCount.
  ///
  /// In en, this message translates to:
  /// **'Files Count'**
  String get filesCount;

  /// No description provided for @fileSentSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'File sent successfully'**
  String get fileSentSuccessfully;

  /// No description provided for @pickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get pickFile;

  /// No description provided for @clipboardSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get clipboardSend;

  /// No description provided for @clipboardTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get clipboardTypeImage;

  /// No description provided for @clipboardTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get clipboardTypeText;

  /// No description provided for @clipboardSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send from clipboard'**
  String get clipboardSendTooltip;

  /// No description provided for @clipboardSettings.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get clipboardSettings;

  /// No description provided for @watchClipboard.
  ///
  /// In en, this message translates to:
  /// **'Offer to send what you copy'**
  String get watchClipboard;

  /// No description provided for @watchClipboardDesc.
  ///
  /// In en, this message translates to:
  /// **'Each time you copy, a button to send what you copied appears on the connected device cards in the Send tab. It reads everything you copy, passwords included.'**
  String get watchClipboardDesc;

  /// No description provided for @pinnedDevices.
  ///
  /// In en, this message translates to:
  /// **'Favorite Devices'**
  String get pinnedDevices;

  /// No description provided for @newDevices.
  ///
  /// In en, this message translates to:
  /// **'New Devices'**
  String get newDevices;

  /// No description provided for @sharedFolder.
  ///
  /// In en, this message translates to:
  /// **'Shared Folder'**
  String get sharedFolder;

  /// No description provided for @uploadToSharedFolder.
  ///
  /// In en, this message translates to:
  /// **'Upload to Shared Folder'**
  String get uploadToSharedFolder;

  /// No description provided for @sharedFolderEmpty.
  ///
  /// In en, this message translates to:
  /// **'Shared folder is empty'**
  String get sharedFolderEmpty;

  /// No description provided for @sharedFolderEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Drop files here or use the upload button'**
  String get sharedFolderEmptyHint;

  /// No description provided for @sharedFolderDisabled.
  ///
  /// In en, this message translates to:
  /// **'Shared folder is disabled'**
  String get sharedFolderDisabled;

  /// No description provided for @allowShareUploads.
  ///
  /// In en, this message translates to:
  /// **'Allow uploads'**
  String get allowShareUploads;

  /// No description provided for @allowShareUploadsDesc.
  ///
  /// In en, this message translates to:
  /// **'Allow other devices to upload files to this folder'**
  String get allowShareUploadsDesc;

  /// No description provided for @enableSharedFolder.
  ///
  /// In en, this message translates to:
  /// **'Enable Shared Folder'**
  String get enableSharedFolder;

  /// No description provided for @enableSharedFolderDesc.
  ///
  /// In en, this message translates to:
  /// **'Share a folder on the network with nearby devices'**
  String get enableSharedFolderDesc;

  /// No description provided for @downloadFromShare.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadFromShare;

  /// No description provided for @uploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'File uploaded successfully'**
  String get uploadSuccess;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @downloadSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String downloadSaved(String path);

  /// No description provided for @browseSharedFolder.
  ///
  /// In en, this message translates to:
  /// **'Browse Shared Folder'**
  String get browseSharedFolder;

  /// No description provided for @deletedFromShare.
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get deletedFromShare;

  /// No description provided for @confirmDeleteFromShare.
  ///
  /// In en, this message translates to:
  /// **'Delete this file from the shared folder?'**
  String get confirmDeleteFromShare;

  /// No description provided for @shareNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Device unreachable'**
  String get shareNetworkError;

  /// No description provided for @shareAccessRefused.
  ///
  /// In en, this message translates to:
  /// **'The owner of the other device refused to open their shared folder'**
  String get shareAccessRefused;

  /// No description provided for @shareNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'The owner of the other device did not answer'**
  String get shareNoAnswer;

  /// No description provided for @shareOffRemote.
  ///
  /// In en, this message translates to:
  /// **'The shared folder is not enabled on the other device'**
  String get shareOffRemote;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'The app version differs between the two devices. Update it on both'**
  String get updateRequired;

  /// No description provided for @versionDiffers.
  ///
  /// In en, this message translates to:
  /// **'Different app version'**
  String get versionDiffers;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @sendDeclined.
  ///
  /// In en, this message translates to:
  /// **'The other device declined'**
  String get sendDeclined;

  /// No description provided for @sendNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'The other device did not answer'**
  String get sendNoAnswer;

  /// No description provided for @sendReceiverBusy.
  ///
  /// In en, this message translates to:
  /// **'The other device is answering another request. Try again shortly'**
  String get sendReceiverBusy;

  /// No description provided for @sendCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sending was cancelled'**
  String get sendCancelled;

  /// No description provided for @sendTooManyFiles.
  ///
  /// In en, this message translates to:
  /// **'You can send at most {max} files at a time'**
  String sendTooManyFiles(int max);

  /// No description provided for @sendNoSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough space on the other device'**
  String get sendNoSpace;

  /// No description provided for @clipboardTextLength.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Text (1 character)} other{Text ({count} characters)}}'**
  String clipboardTextLength(int count);

  /// No description provided for @clipboardCharCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 character} other{{count} characters}}'**
  String clipboardCharCount(int count);

  /// No description provided for @clipboardFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String clipboardFileCount(int count);

  /// No description provided for @chatOpen.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get chatOpen;

  /// No description provided for @chatRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat request'**
  String get chatRequestTitle;

  /// No description provided for @chatRequestQuestion.
  ///
  /// In en, this message translates to:
  /// **'Accept chat?'**
  String get chatRequestQuestion;

  /// No description provided for @requestNewKey.
  ///
  /// In en, this message translates to:
  /// **'This device has a new key'**
  String get requestNewKey;

  /// No description provided for @sendNewKey.
  ///
  /// In en, this message translates to:
  /// **'Not sent: the other device has a new key. Send a message or a file from it to this device, then press Accept here'**
  String get sendNewKey;

  /// No description provided for @shareNewKey.
  ///
  /// In en, this message translates to:
  /// **'Folder not opened: the other device has a new key. Send a message or a file from it to this device, then press Accept here'**
  String get shareNewKey;

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get chatHint;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatEmpty;

  /// No description provided for @chatCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopy;

  /// No description provided for @chatMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatMessages;

  /// No description provided for @chatDeclined.
  ///
  /// In en, this message translates to:
  /// **'The other device declined the chat'**
  String get chatDeclined;

  /// No description provided for @chatFailed.
  ///
  /// In en, this message translates to:
  /// **'The message did not arrive'**
  String get chatFailed;

  /// No description provided for @chatNewMessage.
  ///
  /// In en, this message translates to:
  /// **'Message from {name}'**
  String chatNewMessage(String name);

  /// No description provided for @chatTooLong.
  ///
  /// In en, this message translates to:
  /// **'The message is longer than {max} characters'**
  String chatTooLong(int max);

  /// No description provided for @chatBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get chatBlock;

  /// No description provided for @chatBlockQuestion.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String chatBlockQuestion(String name);

  /// No description provided for @chatBlockDetail.
  ///
  /// In en, this message translates to:
  /// **'Its messages are refused while it is blocked, and you can\'t write to it. The block ends when the app closes.'**
  String get chatBlockDetail;

  /// No description provided for @chatBlocked.
  ///
  /// In en, this message translates to:
  /// **'This device is blocked: no messages to or from it.'**
  String get chatBlocked;

  /// No description provided for @chatUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get chatUnblock;

  /// No description provided for @chatAttach.
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get chatAttach;

  /// No description provided for @chatTransferBusy.
  ///
  /// In en, this message translates to:
  /// **'Another transfer is in progress. Try again when it ends.'**
  String get chatTransferBusy;

  /// No description provided for @chatMoreFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{and 1 more file} other{and {count} more files}}'**
  String chatMoreFiles(int count);

  /// No description provided for @chatFilesFailed.
  ///
  /// In en, this message translates to:
  /// **'Sending did not finish'**
  String get chatFilesFailed;

  /// No description provided for @chatFilesDelivered.
  ///
  /// In en, this message translates to:
  /// **'{delivered} of {total} arrived'**
  String chatFilesDelivered(int delivered, int total);

  /// No description provided for @chatUnread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 new message} other{{count} new messages}}'**
  String chatUnread(int count);

  /// No description provided for @chatPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get chatPaste;

  /// No description provided for @chatClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No copied text'**
  String get chatClipboardEmpty;

  /// No description provided for @chatClose.
  ///
  /// In en, this message translates to:
  /// **'Close chat'**
  String get chatClose;

  /// No description provided for @deviceOptions.
  ///
  /// In en, this message translates to:
  /// **'Device options'**
  String get deviceOptions;

  /// No description provided for @cardFold.
  ///
  /// In en, this message translates to:
  /// **'Collapse card'**
  String get cardFold;

  /// No description provided for @cardExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand card'**
  String get cardExpand;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @closeOptions.
  ///
  /// In en, this message translates to:
  /// **'Close options'**
  String get closeOptions;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @sendPending.
  ///
  /// In en, this message translates to:
  /// **'Send: {name}'**
  String sendPending(String name);

  /// No description provided for @sendAppsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Send 1 app} other{Send {count} apps}}'**
  String sendAppsCount(int count);

  /// No description provided for @findDevices.
  ///
  /// In en, this message translates to:
  /// **'Find devices'**
  String get findDevices;

  /// No description provided for @sidebarCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get sidebarCollapse;

  /// No description provided for @sidebarExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get sidebarExpand;

  /// No description provided for @chatAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get chatAdd;

  /// No description provided for @chatRemoveFile.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String chatRemoveFile(String name);

  /// No description provided for @sendFilesNow.
  ///
  /// In en, this message translates to:
  /// **'Send files'**
  String get sendFilesNow;

  /// No description provided for @senderLine.
  ///
  /// In en, this message translates to:
  /// **'From: {name} · {when}'**
  String senderLine(String name, String when);

  /// No description provided for @whenToday.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String whenToday(String time);

  /// No description provided for @whenYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String whenYesterday(String time);

  /// No description provided for @permBluetoothAdvertise.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Advertise'**
  String get permBluetoothAdvertise;

  /// No description provided for @permBluetoothConnect.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Connect'**
  String get permBluetoothConnect;

  /// No description provided for @permBluetoothScan.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Scan'**
  String get permBluetoothScan;

  /// No description provided for @permNearbyWifi.
  ///
  /// In en, this message translates to:
  /// **'Nearby WiFi Devices'**
  String get permNearbyWifi;

  /// No description provided for @timeSecondsShort.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String timeSecondsShort(int seconds);

  /// No description provided for @timeMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} m'**
  String timeMinutesShort(int minutes);

  /// No description provided for @timeHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String timeHoursShort(int hours);

  /// No description provided for @aboutOfficialWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official Website'**
  String get aboutOfficialWebsite;

  /// No description provided for @aboutGetOnAndroid.
  ///
  /// In en, this message translates to:
  /// **'Get on Android'**
  String get aboutGetOnAndroid;

  /// No description provided for @aboutScanWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Scan with your phone'**
  String get aboutScanWithPhone;

  /// No description provided for @aboutOrTapButton.
  ///
  /// In en, this message translates to:
  /// **'Or tap the button'**
  String get aboutOrTapButton;

  /// No description provided for @updateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get updateCheck;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date ✓'**
  String get updateUpToDate;

  /// No description provided for @updateUpToDateHint.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version'**
  String get updateUpToDateHint;

  /// No description provided for @updateAvailableBang.
  ///
  /// In en, this message translates to:
  /// **'New update available!'**
  String get updateAvailableBang;

  /// No description provided for @updateTapToDownload.
  ///
  /// In en, this message translates to:
  /// **'Tap to download'**
  String get updateTapToDownload;

  /// No description provided for @updateDownloadingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get updateDownloadingEllipsis;

  /// No description provided for @updateReadyToInstall.
  ///
  /// In en, this message translates to:
  /// **'Ready to install'**
  String get updateReadyToInstall;

  /// No description provided for @updateTapToRestart.
  ///
  /// In en, this message translates to:
  /// **'Tap to restart & install'**
  String get updateTapToRestart;

  /// No description provided for @notifFileReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'File received ✅'**
  String get notifFileReceivedTitle;

  /// No description provided for @notifFromDevice.
  ///
  /// In en, this message translates to:
  /// **'{fileName} — from {fromDevice}'**
  String notifFromDevice(String fileName, String fromDevice);

  /// No description provided for @notifSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Sent ✅'**
  String get notifSentTitle;

  /// No description provided for @notifSendFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Send failed ❌'**
  String get notifSendFailedTitle;

  /// No description provided for @notifShareUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'File uploaded to Share 📂'**
  String get notifShareUploadTitle;

  /// No description provided for @tourAgreeMobile.
  ///
  /// In en, this message translates to:
  /// **'I have read the features and agree to grant the required permissions'**
  String get tourAgreeMobile;

  /// No description provided for @tourNearbyWifiDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-discovery via Nearby for phones or WiFi for PC'**
  String get tourNearbyWifiDesc;

  /// No description provided for @tourApkShareDesc.
  ///
  /// In en, this message translates to:
  /// **'Share your installed apps with other devices'**
  String get tourApkShareDesc;

  /// No description provided for @tourMultiPlatformDesc.
  ///
  /// In en, this message translates to:
  /// **'Works on phone, tablet & desktop'**
  String get tourMultiPlatformDesc;

  /// No description provided for @appsNoUserApps.
  ///
  /// In en, this message translates to:
  /// **'No user apps found'**
  String get appsNoUserApps;

  /// No description provided for @updateSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'New Update Available'**
  String get updateSheetTitle;

  /// No description provided for @updateSheetBody.
  ///
  /// In en, this message translates to:
  /// **'A new version of Apex File Share is ready'**
  String get updateSheetBody;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @updateReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Ready'**
  String get updateReadyTitle;

  /// No description provided for @updateInstallsAfterTransfer.
  ///
  /// In en, this message translates to:
  /// **'Update will install after transfer finishes'**
  String get updateInstallsAfterTransfer;

  /// No description provided for @updateDownloadedReady.
  ///
  /// In en, this message translates to:
  /// **'The update is downloaded and ready to install'**
  String get updateDownloadedReady;

  /// No description provided for @installNow.
  ///
  /// In en, this message translates to:
  /// **'Install Now'**
  String get installNow;

  /// No description provided for @permGranted.
  ///
  /// In en, this message translates to:
  /// **'✓ Granted'**
  String get permGranted;

  /// No description provided for @permBlocked.
  ///
  /// In en, this message translates to:
  /// **'✗ Blocked'**
  String get permBlocked;

  /// No description provided for @permTapToGrant.
  ///
  /// In en, this message translates to:
  /// **'← Tap to grant'**
  String get permTapToGrant;

  /// No description provided for @deleteFilesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} files?'**
  String deleteFilesConfirm(int count);

  /// No description provided for @deleteAlsoFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Also delete from device storage'**
  String get deleteAlsoFromDevice;

  /// No description provided for @fromSender.
  ///
  /// In en, this message translates to:
  /// **'From: {name}'**
  String fromSender(String name);

  /// No description provided for @pcVersionGet.
  ///
  /// In en, this message translates to:
  /// **'Get PC Version'**
  String get pcVersionGet;

  /// No description provided for @pcVersionPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Windows & Linux • apexflow.now'**
  String get pcVersionPlatforms;

  /// No description provided for @fileOfTotal.
  ///
  /// In en, this message translates to:
  /// **'File {current} of {total}'**
  String fileOfTotal(int current, int total);

  /// No description provided for @sendingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sendingInProgress;

  /// No description provided for @tvTourBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'Before You Start'**
  String get tvTourBeforeStart;

  /// No description provided for @tvTourBeforeStartHint.
  ///
  /// In en, this message translates to:
  /// **'Scroll through the features\nthen agree to continue'**
  String get tvTourBeforeStartHint;

  /// No description provided for @tvTourAgree.
  ///
  /// In en, this message translates to:
  /// **'I agree to terms'**
  String get tvTourAgree;

  /// No description provided for @tvTourFastDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Fast auto-discovery'**
  String get tvTourFastDiscovery;

  /// No description provided for @tvTourShareApps.
  ///
  /// In en, this message translates to:
  /// **'Share your installed apps'**
  String get tvTourShareApps;

  /// No description provided for @tvTourDevices.
  ///
  /// In en, this message translates to:
  /// **'Phone, tablet & desktop'**
  String get tvTourDevices;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Empty folder'**
  String get emptyFolder;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
