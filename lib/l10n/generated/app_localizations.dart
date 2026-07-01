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

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

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

  /// No description provided for @discovering.
  ///
  /// In en, this message translates to:
  /// **'Discovering...'**
  String get discovering;

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

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get noDevicesFound;

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
  /// **'Wait to receive files from other devices'**
  String get instruction4;

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

  /// No description provided for @restartingSystem.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get restartingSystem;

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

  /// No description provided for @folderSent.
  ///
  /// In en, this message translates to:
  /// **'Folder sent'**
  String get folderSent;

  /// No description provided for @compressingFolder.
  ///
  /// In en, this message translates to:
  /// **'Compressing folder...'**
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

  /// No description provided for @systemStartFailed.
  ///
  /// In en, this message translates to:
  /// **'System start failed'**
  String get systemStartFailed;

  /// No description provided for @fileReceived.
  ///
  /// In en, this message translates to:
  /// **'File received!'**
  String get fileReceived;

  /// No description provided for @openFiles.
  ///
  /// In en, this message translates to:
  /// **'Open Files'**
  String get openFiles;

  /// No description provided for @openFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get openFileFailed;

  /// No description provided for @openLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open location'**
  String get openLocationFailed;

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
  /// **'Sending...'**
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

  /// No description provided for @availableDevices.
  ///
  /// In en, this message translates to:
  /// **'Available Devices'**
  String get availableDevices;

  /// No description provided for @systemNotRunning.
  ///
  /// In en, this message translates to:
  /// **'System not running'**
  String get systemNotRunning;

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
  /// **'Pick File'**
  String get pickFile;
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
