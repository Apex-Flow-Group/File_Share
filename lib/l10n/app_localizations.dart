import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);
  
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }
  
  static const Map<String, Map<String, String>> _localizedValues = {
    'ar': {
      'appTitle': 'Apex Transfer',
      'send': 'إرسال',
      'receive': 'استقبال',
      'files': 'ملفات',
      'settings': 'الإعدادات',
      'about': 'حول',
      'support': 'الدعم',
      'home': 'الرئيسية',
      'thisDevice': 'هذا الجهاز',
      'deviceName': 'اسم الجهاز',
      'deviceType': 'نوع الجهاز',
      'status': 'الحالة',
      'ipAddress': 'عنوان IP',
      'discovering': 'يبحث...',
      'idle': 'خامل',
      'unknown': 'غير معروف',
      'unknownDevice': 'جهاز غير معروف',
      'phone': 'هاتف',
      'tablet': 'تابلت',
      'desktop': 'كمبيوتر',
      'noDevicesFound': 'لم يتم العثور على أجهزة',
      'makeSureDevicesOnSameNetwork': 'تأكد من أن الأجهزة على نفس الشبكة',
      'connecting': 'يتصل...',
      'connected': 'متصل',
      'tapToConnect': 'اضغط للاتصال',
      'sendFile': 'إرسال ملف',
      'sendText': 'إرسال نص',
      'selectDevice': 'اختر الجهاز',
      'cancel': 'إلغاء',
      'filePickError': 'خطأ في اختيار الملف',
      'sendingFileTo': 'إرسال ملف إلى',
      'sendingTextTo': 'إرسال نص إلى',
      'noDevicesConnected': 'لا توجد أجهزة متصلة',
      'howToReceive': 'كيفية الاستقبال',
      'instruction1': 'تأكد من اتصال جميع الأجهزة بنفس شبكة WiFi',
      'instruction2': 'افتح التطبيق على الأجهزة الأخرى',
      'instruction3': 'سيتم اكتشاف الأجهزة تلقائياً',
      'instruction4': 'انتظر استقبال الملفات من الأجهزة الأخرى',
      'recentTransfers': 'النقل الأخير',
      'noRecentTransfers': 'لا توجد عمليات نقل حديثة',
      'discoveryFailed': 'فشل البحث',
      'startDiscovery': 'بدء البحث',
      'stopDiscovery': 'إيقاف البحث',
      'connectedTo': 'متصل بـ',
      'connectionFailed': 'فشل الاتصال',
      'connectionError': 'خطأ في الاتصال',
      'deleteFiles': 'حذف الملفات',
      'filesCount': 'عدد الملفات',
      'deletePermanent': 'حذف نهائي',
      'deleteWarning': 'سيتم حذف الملفات نهائياً!',
      'noFiles': 'لا توجد ملفات',
      'openFolder': 'فتح المجلد',
      'openFile': 'فتح الملف',
      'selected': 'محدد',
      'sortBy': 'ترتيب حسب',
      'date': 'التاريخ',
      'size': 'الحجم',
      'type': 'النوع',
      'name': 'الاسم',
      'save': 'حفظ',
      'appearance': 'المظهر',
      'language': 'اللغة',
      'theme': 'السمة',
      'permissions': 'الصلاحيات',
      'appPermissions': 'صلاحيات التطبيق',
      'managePermissions': 'إدارة الصلاحيات',
      'systemSettings': 'إعدادات النظام',
      'openSystemSettings': 'فتح إعدادات النظام',
      'network': 'الشبكة',
      'wifiDirect': 'WiFi Direct',
      'wifiDirectDesc': 'اتصال مباشر بين الأجهزة',
      'localNetwork': 'الشبكة المحلية',
      'localNetworkDesc': 'اكتشاف الأجهزة على نفس الشبكة',
      'selectLanguage': 'اختر اللغة',
      'selectTheme': 'اختر السمة',
      'light': 'فاتح',
      'dark': 'داكن',
      'system': 'النظام',
      'location': 'الموقع',
      'bluetooth': 'بلوتوث',
      'storageLabel': 'التخزين',
      'nearbyDevices': 'الأجهزة القريبة',
      'close': 'إغلاق',
      'openSettings': 'فتح الإعدادات',
      'connectedToWifi': 'متصل بالواي فاي',
      'notConnected': 'غير متصل',
      'defaultDevice': 'جهاز',
      'addDevice': 'إضافة جهاز',
      'add': 'إضافة',
      'fileSent': 'تم إرسال الملف',
      'sendFailed': 'فشل الإرسال',
      'accept': 'قبول',
      'reject': 'رفض',
      'selectAll': 'تحديد الكل',
      'deleteConfirmation': 'هل تريد حذف',
      'delete': 'حذف',
      'filesDeleted': 'ملف تم حذفه',
      'sortPreferenceSaved': 'تم حفظ تفضيلات الترتيب',
      'deleteFromFolders': 'حذف من المجلدات أيضاً',
      'permanentDeleteWarning': '⚠️ سيتم حذف الملفات نهائياً من التخزين',
      'deleteFromListOnly': 'سيتم حذف الملفات من القائمة فقط',
      'cannotUndoWarning': 'تحذير: هذا الإجراء لا يمكن التراجع عنه',
      'connectionRequest': 'طلب اتصال',
      'deviceWantsToConnect': 'يريد الجهاز الاتصال بك:',
      'acceptConnection': 'هل تريد قبول الاتصال؟',
      'connectionFailedTitle': 'فشل الاتصال',
      'couldNotConnect': 'لم يتمكن من الاتصال بـ',
      'ok': 'حسناً',
      'reconnectFailed': 'فشل إعادة الاتصال',
      'restartingSystem': 'جاري إعادة تشغيل النظام...',
      'restartFailed': 'فشلت إعادة التشغيل',
      'sendApp': 'إرسال تطبيق',
      'installedApps': 'التطبيقات المثبتة',
      'noApps': 'لا توجد تطبيقات',
      'sendingAppTo': 'إرسال تطبيق إلى',
      'appSent': 'تم إرسال التطبيق',
      'welcomeToApex': 'مرحباً بك في Apex Transfer',
      'fastAndSecure': 'سريع وآمن وبدون إنترنت',
      'startTour': 'ابدأ الجولة',
      'feature1Title': 'نقل سريع',
      'feature1Desc': 'إرسال الملفات بسرعة عالية عبر WiFi',
      'feature2Title': 'بدون إنترنت',
      'feature2Desc': 'يعمل على الشبكة المحلية فقط',
      'feature3Title': 'آمن ومشفر',
      'feature3Desc': 'حماية كاملة لملفاتك',
      'skip': 'تخطي',
      'next': 'التالي',
      'finish': 'ابدأ الآن',
      'textCopied': 'تم النسخ',
      'noMessages': 'لا توجد رسائل',
      'typeMessage': 'اكتب رسالة...',
      'systemStartFailed': 'فشل بدء النظام',
      'fileReceived': 'تم استلام ملف!',
      'openFiles': 'فتح الملفات',
      'openFileFailed': 'فشل فتح الملف',
      'openLocationFailed': 'فشل فتح الموقع',
      'filesDeletedCount': 'ملف تم حذفه',
      'noDevicesAvailable': 'لا توجد أجهزة متاحة',
      'filePickFailed': 'فشل اختيار الملف',
      'sendingFile': 'جاري إرسال الملف إلى',
      'fileSentSuccess': 'تم إرسال الملف بنجاح',
      'fileSendFailed': 'فشل إرسال الملف',
      'selectDeviceFirst': 'اختر الجهاز أولاً',
      'chooseDevice': 'اختر الجهاز',
      'from': 'من',
      'savedIn': 'تم الحفظ في',
      'filesTab': 'تبويب الملفات',
      'receiving': 'جاري الاستقبال...',
      'fileSize': 'حجم الملف',
      'contactUs': 'اتصل بنا',
      'weAreHappyToHear': 'نسعد بتواصلك معنا',
      'yourName': 'الاسم',
      'email': 'البريد الإلكتروني',
      'category': 'الفئة',
      'subject': 'الموضوع',
      'message': 'الرسالة',
      'sending': 'جاري الإرسال...',
      'sendMessage': 'إرسال',
      'fieldRequired': 'هذا الحقل مطلوب',
      'emailOpened': 'تم فتح تطبيق البريد',
      'inquiry': 'استفسار',
      'technicalIssue': 'مشكلة تقنية',
      'suggestion': 'اقتراح',
      'other': 'أخرى',
      'aboutApp': 'حول التطبيق',
      'appDescription': 'تطبيق مشاركة الملفات السريع والآمن',
      'importantLinks': 'الروابط المهمة',
      'privacyPolicy': 'سياسة الخصوصية',
      'termsOfService': 'شروط الخدمة',
      'legalInfo': 'المعلومات القانونية',
      'disclaimer': 'إخلاء المسؤولية',
      'disclaimerText': 'هذا التطبيق يُقدم "كما هو" بدون أي ضمانات. Apex Flow Group غير مسؤولة عن أي خسائر أو أضرار ناجمة عن استخدام التطبيق.',
      'copyright': 'حقوق النشر',
      'copyrightText': '© 2025 Apex Flow Group. جميع الحقوق محفوظة.',
      'madeInArabWorld': 'صُنع في العالم العربي',
      'pressMenuForSettings': 'اضغط MENU للإعدادات',
      'notConnectedToWiFi': 'غير متصل بالواي فاي',
      'mustConnectToWiFi': 'يجب الاتصال بشبكة WiFi لاستخدام التطبيق',
      'openWiFiSettings': 'فتح إعدادات WiFi',
      'createHotspot': 'إنشاء نقطة اتصال',
      'music': 'الموسيقى',
      'songs': 'الأغاني',
      'albums': 'الألبومات',
      'artists': 'الفنانين',
      'folders': 'المجلدات',
      'noMusic': 'لا توجد موسيقى',
      'noAlbums': 'لا توجد ألبومات',
      'noArtists': 'لا يوجد فنانين',
      'searchMusic': 'بحث في الموسيقى...',
      'playAll': 'تشغيل الكل',
      'shuffle': 'عشوائي',
      'addToQueue': 'إضافة إلى قائمة الانتظار',
      'songInfo': 'معلومات الأغنية',
      'selectFolder': 'اختيار مجلد',
      'customFolder': 'مجلد مخصص',
      'rescanLibrary': 'إعادة فحص المكتبة',
      'defaultFolders': 'المجلدات الافتراضية',
      'enterPath': 'أدخل مسار المجلد:',
      'examples': 'أمثلة:',
      'tipCopyPath': '💡 نصيحة: انسخ المسار من مدير الملفات',
      'foundSongs': 'تم العثور على {count} أغنية',
      'scanFailed': 'فشل فحص المجلد',
      'play': 'تشغيل',
      'pause': 'إيقاف مؤقت',
      'previous': 'السابق',
      'queue': 'قائمة الانتظار',
      'nowPlaying': 'قيد التشغيل',
      'unknownArtist': 'فنان غير معروف',
      'unknownAlbum': 'ألبوم غير معروف',
      'track': 'مسار',
      'tracks': 'مسارات',
      'album': 'ألبوم',
      'artist': 'فنان',
      'duration': 'المدة',
      'path': 'المسار',
      'addedToQueue': 'تمت الإضافة إلى قائمة الانتظار',
      'exitApp': 'الخروج من التطبيق',
      'exitConfirmation': 'هل تريد الخروج من التطبيق؟',
      'exit': 'خروج',
      'availableDevices': 'الأجهزة المتاحة',
      'pickFile': 'اختيار ملف',
      'systemNotRunning': 'النظام لا يعمل',
      'fileSentSuccessfully': 'تم إرسال الملف بنجاح',
    },
    'en': {
      'appTitle': 'Apex Transfer',
      'send': 'Send',
      'receive': 'Receive',
      'files': 'Files',
      'settings': 'Settings',
      'about': 'About',
      'support': 'Support',
      'home': 'Home',
      'thisDevice': 'This Device',
      'deviceName': 'Device Name',
      'deviceType': 'Device Type',
      'status': 'Status',
      'ipAddress': 'IP Address',
      'discovering': 'Discovering...',
      'idle': 'Idle',
      'unknown': 'Unknown',
      'unknownDevice': 'Unknown Device',
      'phone': 'Phone',
      'tablet': 'Tablet',
      'desktop': 'Desktop',
      'noDevicesFound': 'No devices found',
      'makeSureDevicesOnSameNetwork': 'Make sure devices are on the same network',
      'connecting': 'Connecting...',
      'connected': 'Connected',
      'tapToConnect': 'Tap to connect',
      'sendFile': 'Send File',
      'sendText': 'Send Text',
      'selectDevice': 'Select Device',
      'cancel': 'Cancel',
      'filePickError': 'File pick error',
      'sendingFileTo': 'Sending file to',
      'sendingTextTo': 'Sending text to',
      'noDevicesConnected': 'No devices connected',
      'howToReceive': 'How to Receive',
      'instruction1': 'Make sure all devices are connected to the same WiFi network',
      'instruction2': 'Open the app on other devices',
      'instruction3': 'Devices will be discovered automatically',
      'instruction4': 'Wait to receive files from other devices',
      'recentTransfers': 'Recent Transfers',
      'noRecentTransfers': 'No recent transfers',
      'discoveryFailed': 'Discovery failed',
      'startDiscovery': 'Start Discovery',
      'stopDiscovery': 'Stop Discovery',
      'connectedTo': 'Connected to',
      'connectionFailed': 'Connection failed',
      'connectionError': 'Connection error',
      'deleteFiles': 'Delete Files',
      'filesCount': 'Files Count',
      'deletePermanent': 'Delete Permanently',
      'deleteWarning': 'Files will be permanently deleted!',
      'noFiles': 'No files',
      'openFolder': 'Open Folder',
      'openFile': 'Open File',
      'selected': 'selected',
      'sortBy': 'Sort by',
      'date': 'Date',
      'size': 'Size',
      'type': 'Type',
      'name': 'Name',
      'save': 'Save',
      'appearance': 'Appearance',
      'language': 'Language',
      'theme': 'Theme',
      'permissions': 'Permissions',
      'appPermissions': 'App Permissions',
      'managePermissions': 'Manage Permissions',
      'systemSettings': 'System Settings',
      'openSystemSettings': 'Open System Settings',
      'network': 'Network',
      'wifiDirect': 'WiFi Direct',
      'wifiDirectDesc': 'Direct connection between devices',
      'localNetwork': 'Local Network',
      'localNetworkDesc': 'Discover devices on same network',
      'selectLanguage': 'Select Language',
      'selectTheme': 'Select Theme',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'location': 'Location',
      'bluetooth': 'Bluetooth',
      'storageLabel': 'Storage',
      'nearbyDevices': 'Nearby Devices',
      'close': 'Close',
      'openSettings': 'Open Settings',
      'connectedToWifi': 'Connected to WiFi',
      'notConnected': 'Not Connected',
      'defaultDevice': 'Device',
      'addDevice': 'Add Device',
      'add': 'Add',
      'fileSent': 'File sent',
      'sendFailed': 'Send failed',
      'accept': 'Accept',
      'reject': 'Reject',
      'selectAll': 'Select All',
      'deleteConfirmation': 'Do you want to delete',
      'delete': 'Delete',
      'filesDeleted': 'files deleted',
      'sortPreferenceSaved': 'Sort preferences saved',
      'deleteFromFolders': 'Delete from folders too',
      'permanentDeleteWarning': '⚠️ Files will be permanently deleted from storage',
      'deleteFromListOnly': 'Files will be removed from list only',
      'cannotUndoWarning': 'Warning: This action cannot be undone',
      'connectionRequest': 'Connection Request',
      'deviceWantsToConnect': 'Device wants to connect:',
      'acceptConnection': 'Do you want to accept the connection?',
      'connectionFailedTitle': 'Connection Failed',
      'couldNotConnect': 'Could not connect to',
      'ok': 'OK',
      'reconnectFailed': 'Reconnect failed',
      'restartingSystem': 'Restarting system...',
      'restartFailed': 'Restart failed',
      'sendApp': 'Send App',
      'installedApps': 'Installed Apps',
      'noApps': 'No apps',
      'sendingAppTo': 'Sending app to',
      'appSent': 'App sent',
      'welcomeToApex': 'Welcome to Apex Transfer',
      'fastAndSecure': 'Fast, Secure & Offline',
      'startTour': 'Start Tour',
      'feature1Title': 'Fast Transfer',
      'feature1Desc': 'Send files at high speed via WiFi',
      'feature2Title': 'No Internet',
      'feature2Desc': 'Works on local network only',
      'feature3Title': 'Secure & Encrypted',
      'feature3Desc': 'Full protection for your files',
      'skip': 'Skip',
      'next': 'Next',
      'finish': 'Get Started',
      'textCopied': 'Text copied',
      'noMessages': 'No messages',
      'typeMessage': 'Type a message...',
      'systemStartFailed': 'System start failed',
      'fileReceived': 'File received!',
      'openFiles': 'Open Files',
      'openFileFailed': 'Failed to open file',
      'openLocationFailed': 'Failed to open location',
      'filesDeletedCount': 'files deleted',
      'noDevicesAvailable': 'No devices available',
      'filePickFailed': 'Failed to pick file',
      'sendingFile': 'Sending file to',
      'fileSentSuccess': 'File sent successfully',
      'fileSendFailed': 'Failed to send file',
      'selectDeviceFirst': 'Select device first',
      'chooseDevice': 'Choose Device',
      'from': 'From',
      'savedIn': 'Saved in',
      'filesTab': 'Files tab',
      'receiving': 'Receiving...',
      'fileSize': 'File Size',
      'contactUs': 'Contact Us',
      'weAreHappyToHear': 'We are happy to hear from you',
      'yourName': 'Name',
      'email': 'Email',
      'category': 'Category',
      'subject': 'Subject',
      'message': 'Message',
      'sending': 'Sending...',
      'sendMessage': 'Send',
      'fieldRequired': 'This field is required',
      'emailOpened': 'Email app opened',
      'inquiry': 'Inquiry',
      'technicalIssue': 'Technical Issue',
      'suggestion': 'Suggestion',
      'other': 'Other',
      'aboutApp': 'About App',
      'appDescription': 'Fast and secure file sharing app',
      'importantLinks': 'Important Links',
      'privacyPolicy': 'Privacy Policy',
      'termsOfService': 'Terms of Service',
      'legalInfo': 'Legal Information',
      'disclaimer': 'Disclaimer',
      'disclaimerText': 'This app is provided "as is" without any warranties. Apex Flow Group is not responsible for any losses or damages resulting from the use of the app.',
      'copyright': 'Copyright',
      'copyrightText': '© 2025 Apex Flow Group. All rights reserved.',
      'madeInArabWorld': 'Made in the Arab World',
      'pressMenuForSettings': 'Press MENU for Settings',
      'notConnectedToWiFi': 'Not Connected to WiFi',
      'mustConnectToWiFi': 'You must connect to a WiFi network to use the app',
      'openWiFiSettings': 'Open WiFi Settings',
      'createHotspot': 'Create Hotspot',
      'music': 'Music',
      'songs': 'Songs',
      'albums': 'Albums',
      'artists': 'Artists',
      'folders': 'Folders',
      'noMusic': 'No music',
      'noAlbums': 'No albums',
      'noArtists': 'No artists',
      'searchMusic': 'Search music...',
      'playAll': 'Play All',
      'shuffle': 'Shuffle',
      'addToQueue': 'Add to Queue',
      'songInfo': 'Song Info',
      'selectFolder': 'Select Folder',
      'customFolder': 'Custom Folder',
      'rescanLibrary': 'Rescan Library',
      'defaultFolders': 'Default Folders',
      'enterPath': 'Enter folder path:',
      'examples': 'Examples:',
      'tipCopyPath': '💡 Tip: Copy path from file manager',
      'foundSongs': 'Found {count} songs',
      'scanFailed': 'Scan failed',
      'play': 'Play',
      'pause': 'Pause',
      'previous': 'Previous',
      'queue': 'Queue',
      'nowPlaying': 'Now Playing',
      'unknownArtist': 'Unknown Artist',
      'unknownAlbum': 'Unknown Album',
      'track': 'Track',
      'tracks': 'Tracks',
      'album': 'Album',
      'artist': 'Artist',
      'duration': 'Duration',
      'path': 'Path',
      'addedToQueue': 'Added to queue',
      'exitApp': 'Exit App',
      'exitConfirmation': 'Do you want to exit the app?',
      'exit': 'Exit',
      'availableDevices': 'Available Devices',
      'pickFile': 'Pick File',
      'systemNotRunning': 'System not running',
      'fileSentSuccessfully': 'File sent successfully',
    },
  };
  
  String get appTitle => _localizedValues[locale.languageCode]?['appTitle'] ?? 'Apex Transfer';
  String get send => _localizedValues[locale.languageCode]?['send'] ?? 'Send';
  String get receive => _localizedValues[locale.languageCode]?['receive'] ?? 'Receive';
  String get files => _localizedValues[locale.languageCode]?['files'] ?? 'Files';
  String get settings => _localizedValues[locale.languageCode]?['settings'] ?? 'Settings';
  String get about => _localizedValues[locale.languageCode]?['about'] ?? 'About';
  String get support => _localizedValues[locale.languageCode]?['support'] ?? 'Support';
  String get home => _localizedValues[locale.languageCode]?['home'] ?? 'Home';
  String get thisDevice => _localizedValues[locale.languageCode]?['thisDevice'] ?? 'This Device';
  String get deviceName => _localizedValues[locale.languageCode]?['deviceName'] ?? 'Device Name';
  String get deviceType => _localizedValues[locale.languageCode]?['deviceType'] ?? 'Device Type';
  String get status => _localizedValues[locale.languageCode]?['status'] ?? 'Status';
  String get ipAddress => _localizedValues[locale.languageCode]?['ipAddress'] ?? 'IP Address';
  String get discovering => _localizedValues[locale.languageCode]?['discovering'] ?? 'Discovering...';
  String get idle => _localizedValues[locale.languageCode]?['idle'] ?? 'Idle';
  String get unknown => _localizedValues[locale.languageCode]?['unknown'] ?? 'Unknown';
  String get unknownDevice => _localizedValues[locale.languageCode]?['unknownDevice'] ?? 'Unknown Device';
  String get phone => _localizedValues[locale.languageCode]?['phone'] ?? 'Phone';
  String get tablet => _localizedValues[locale.languageCode]?['tablet'] ?? 'Tablet';
  String get desktop => _localizedValues[locale.languageCode]?['desktop'] ?? 'Desktop';
  String get noDevicesFound => _localizedValues[locale.languageCode]?['noDevicesFound'] ?? 'No devices found';
  String get makeSureDevicesOnSameNetwork => _localizedValues[locale.languageCode]?['makeSureDevicesOnSameNetwork'] ?? 'Make sure devices are on the same network';
  String get connecting => _localizedValues[locale.languageCode]?['connecting'] ?? 'Connecting...';
  String get connected => _localizedValues[locale.languageCode]?['connected'] ?? 'Connected';
  String get tapToConnect => _localizedValues[locale.languageCode]?['tapToConnect'] ?? 'Tap to connect';
  String get sendFile => _localizedValues[locale.languageCode]?['sendFile'] ?? 'Send File';
  String get sendText => _localizedValues[locale.languageCode]?['sendText'] ?? 'Send Text';
  String get selectDevice => _localizedValues[locale.languageCode]?['selectDevice'] ?? 'Select Device';
  String get cancel => _localizedValues[locale.languageCode]?['cancel'] ?? 'Cancel';
  String get filePickError => _localizedValues[locale.languageCode]?['filePickError'] ?? 'File pick error';
  String get sendingFileTo => _localizedValues[locale.languageCode]?['sendingFileTo'] ?? 'Sending file to';
  String get sendingTextTo => _localizedValues[locale.languageCode]?['sendingTextTo'] ?? 'Sending text to';
  String get noDevicesConnected => _localizedValues[locale.languageCode]?['noDevicesConnected'] ?? 'No devices connected';
  String get howToReceive => _localizedValues[locale.languageCode]?['howToReceive'] ?? 'How to Receive';
  String get instruction1 => _localizedValues[locale.languageCode]?['instruction1'] ?? 'Make sure all devices are connected to the same WiFi network';
  String get instruction2 => _localizedValues[locale.languageCode]?['instruction2'] ?? 'Open the app on other devices';
  String get instruction3 => _localizedValues[locale.languageCode]?['instruction3'] ?? 'Devices will be discovered automatically';
  String get instruction4 => _localizedValues[locale.languageCode]?['instruction4'] ?? 'Wait to receive files from other devices';
  String get recentTransfers => _localizedValues[locale.languageCode]?['recentTransfers'] ?? 'Recent Transfers';
  String get noRecentTransfers => _localizedValues[locale.languageCode]?['noRecentTransfers'] ?? 'No recent transfers';
  String get discoveryFailed => _localizedValues[locale.languageCode]?['discoveryFailed'] ?? 'Discovery failed';
  String get startDiscovery => _localizedValues[locale.languageCode]?['startDiscovery'] ?? 'Start Discovery';
  String get stopDiscovery => _localizedValues[locale.languageCode]?['stopDiscovery'] ?? 'Stop Discovery';
  String get connectedTo => _localizedValues[locale.languageCode]?['connectedTo'] ?? 'Connected to';
  String get connectionFailed => _localizedValues[locale.languageCode]?['connectionFailed'] ?? 'Connection failed';
  String get connectionError => _localizedValues[locale.languageCode]?['connectionError'] ?? 'Connection error';
  String get deleteFiles => _localizedValues[locale.languageCode]?['deleteFiles'] ?? 'Delete Files';
  String get filesCount => _localizedValues[locale.languageCode]?['filesCount'] ?? 'Files Count';
  String get deletePermanent => _localizedValues[locale.languageCode]?['deletePermanent'] ?? 'Delete Permanently';
  String get deleteWarning => _localizedValues[locale.languageCode]?['deleteWarning'] ?? 'Files will be permanently deleted!';
  String get noFiles => _localizedValues[locale.languageCode]?['noFiles'] ?? 'No files';
  String get openFolder => _localizedValues[locale.languageCode]?['openFolder'] ?? 'Open Folder';
  String get openFile => _localizedValues[locale.languageCode]?['openFile'] ?? 'Open File';
  String get selected => _localizedValues[locale.languageCode]?['selected'] ?? 'selected';
  String get sortBy => _localizedValues[locale.languageCode]?['sortBy'] ?? 'Sort by';
  String get date => _localizedValues[locale.languageCode]?['date'] ?? 'Date';
  String get size => _localizedValues[locale.languageCode]?['size'] ?? 'Size';
  String get type => _localizedValues[locale.languageCode]?['type'] ?? 'Type';
  String get name => _localizedValues[locale.languageCode]?['name'] ?? 'Name';
  String get save => _localizedValues[locale.languageCode]?['save'] ?? 'Save';
  String get appearance => _localizedValues[locale.languageCode]?['appearance'] ?? 'Appearance';
  String get language => _localizedValues[locale.languageCode]?['language'] ?? 'Language';
  String get theme => _localizedValues[locale.languageCode]?['theme'] ?? 'Theme';
  String get permissions => _localizedValues[locale.languageCode]?['permissions'] ?? 'Permissions';
  String get appPermissions => _localizedValues[locale.languageCode]?['appPermissions'] ?? 'App Permissions';
  String get managePermissions => _localizedValues[locale.languageCode]?['managePermissions'] ?? 'Manage Permissions';
  String get systemSettings => _localizedValues[locale.languageCode]?['systemSettings'] ?? 'System Settings';
  String get openSystemSettings => _localizedValues[locale.languageCode]?['openSystemSettings'] ?? 'Open System Settings';
  String get network => _localizedValues[locale.languageCode]?['network'] ?? 'Network';
  String get wifiDirect => _localizedValues[locale.languageCode]?['wifiDirect'] ?? 'WiFi Direct';
  String get wifiDirectDesc => _localizedValues[locale.languageCode]?['wifiDirectDesc'] ?? 'Direct connection between devices';
  String get localNetwork => _localizedValues[locale.languageCode]?['localNetwork'] ?? 'Local Network';
  String get localNetworkDesc => _localizedValues[locale.languageCode]?['localNetworkDesc'] ?? 'Discover devices on same network';
  String get selectLanguage => _localizedValues[locale.languageCode]?['selectLanguage'] ?? 'Select Language';
  String get selectTheme => _localizedValues[locale.languageCode]?['selectTheme'] ?? 'Select Theme';
  String get light => _localizedValues[locale.languageCode]?['light'] ?? 'Light';
  String get dark => _localizedValues[locale.languageCode]?['dark'] ?? 'Dark';
  String get system => _localizedValues[locale.languageCode]?['system'] ?? 'System';
  String get location => _localizedValues[locale.languageCode]?['location'] ?? 'Location';
  String get bluetooth => _localizedValues[locale.languageCode]?['bluetooth'] ?? 'Bluetooth';
  String get storageLabel => _localizedValues[locale.languageCode]?['storageLabel'] ?? 'Storage';
  String get nearbyDevices => _localizedValues[locale.languageCode]?['nearbyDevices'] ?? 'Nearby Devices';
  String get close => _localizedValues[locale.languageCode]?['close'] ?? 'Close';
  String get openSettings => _localizedValues[locale.languageCode]?['openSettings'] ?? 'Open Settings';
  String get connectedToWifi => _localizedValues[locale.languageCode]?['connectedToWifi'] ?? 'Connected to WiFi';
  String get notConnected => _localizedValues[locale.languageCode]?['notConnected'] ?? 'Not Connected';
  String get defaultDevice => _localizedValues[locale.languageCode]?['defaultDevice'] ?? 'Device';
  String get addDevice => _localizedValues[locale.languageCode]?['addDevice'] ?? 'Add Device';
  String get add => _localizedValues[locale.languageCode]?['add'] ?? 'Add';
  String get fileSent => _localizedValues[locale.languageCode]?['fileSent'] ?? 'File sent';
  String get sendFailed => _localizedValues[locale.languageCode]?['sendFailed'] ?? 'Send failed';
  String get accept => _localizedValues[locale.languageCode]?['accept'] ?? 'Accept';
  String get reject => _localizedValues[locale.languageCode]?['reject'] ?? 'Reject';
  String get selectAll => _localizedValues[locale.languageCode]?['selectAll'] ?? 'Select All';
  String get deleteConfirmation => _localizedValues[locale.languageCode]?['deleteConfirmation'] ?? 'Do you want to delete';
  String get delete => _localizedValues[locale.languageCode]?['delete'] ?? 'Delete';
  String get filesDeleted => _localizedValues[locale.languageCode]?['filesDeleted'] ?? 'files deleted';
  String get sortPreferenceSaved => _localizedValues[locale.languageCode]?['sortPreferenceSaved'] ?? 'Sort preferences saved';
  String get deleteFromFolders => _localizedValues[locale.languageCode]?['deleteFromFolders'] ?? 'Delete from folders too';
  String get permanentDeleteWarning => _localizedValues[locale.languageCode]?['permanentDeleteWarning'] ?? 'Files will be permanently deleted from storage';
  String get deleteFromListOnly => _localizedValues[locale.languageCode]?['deleteFromListOnly'] ?? 'Files will be removed from list only';
  String get cannotUndoWarning => _localizedValues[locale.languageCode]?['cannotUndoWarning'] ?? 'Warning: This action cannot be undone';
  String get connectionRequest => _localizedValues[locale.languageCode]?['connectionRequest'] ?? 'Connection Request';
  String get deviceWantsToConnect => _localizedValues[locale.languageCode]?['deviceWantsToConnect'] ?? 'Device wants to connect:';
  String get acceptConnection => _localizedValues[locale.languageCode]?['acceptConnection'] ?? 'Do you want to accept the connection?';
  String get connectionFailedTitle => _localizedValues[locale.languageCode]?['connectionFailedTitle'] ?? 'Connection Failed';
  String get couldNotConnect => _localizedValues[locale.languageCode]?['couldNotConnect'] ?? 'Could not connect to';
  String get ok => _localizedValues[locale.languageCode]?['ok'] ?? 'OK';
  String get reconnectFailed => _localizedValues[locale.languageCode]?['reconnectFailed'] ?? 'Reconnect failed';
  String get restartingSystem => _localizedValues[locale.languageCode]?['restartingSystem'] ?? 'Restarting system...';
  String get restartFailed => _localizedValues[locale.languageCode]?['restartFailed'] ?? 'Restart failed';
  String get sendApp => _localizedValues[locale.languageCode]?['sendApp'] ?? 'Send App';
  String get installedApps => _localizedValues[locale.languageCode]?['installedApps'] ?? 'Installed Apps';
  String get noApps => _localizedValues[locale.languageCode]?['noApps'] ?? 'No apps';
  String get sendingAppTo => _localizedValues[locale.languageCode]?['sendingAppTo'] ?? 'Sending app to';
  String get appSent => _localizedValues[locale.languageCode]?['appSent'] ?? 'App sent';
  String get welcomeToApex => _localizedValues[locale.languageCode]?['welcomeToApex'] ?? 'Welcome to Apex Transfer';
  String get fastAndSecure => _localizedValues[locale.languageCode]?['fastAndSecure'] ?? 'Fast, Secure & Offline';
  String get startTour => _localizedValues[locale.languageCode]?['startTour'] ?? 'Start Tour';
  String get feature1Title => _localizedValues[locale.languageCode]?['feature1Title'] ?? 'Fast Transfer';
  String get feature1Desc => _localizedValues[locale.languageCode]?['feature1Desc'] ?? 'Send files at high speed via WiFi';
  String get feature2Title => _localizedValues[locale.languageCode]?['feature2Title'] ?? 'No Internet';
  String get feature2Desc => _localizedValues[locale.languageCode]?['feature2Desc'] ?? 'Works on local network only';
  String get feature3Title => _localizedValues[locale.languageCode]?['feature3Title'] ?? 'Secure & Encrypted';
  String get feature3Desc => _localizedValues[locale.languageCode]?['feature3Desc'] ?? 'Full protection for your files';
  String get skip => _localizedValues[locale.languageCode]?['skip'] ?? 'Skip';
  String get next => _localizedValues[locale.languageCode]?['next'] ?? 'Next';
  String get finish => _localizedValues[locale.languageCode]?['finish'] ?? 'Get Started';
  String get textCopied => _localizedValues[locale.languageCode]?['textCopied'] ?? 'Text copied';
  String get noMessages => _localizedValues[locale.languageCode]?['noMessages'] ?? 'No messages';
  String get typeMessage => _localizedValues[locale.languageCode]?['typeMessage'] ?? 'Type a message...';
  String get systemStartFailed => _localizedValues[locale.languageCode]?['systemStartFailed'] ?? 'System start failed';
  String get fileReceived => _localizedValues[locale.languageCode]?['fileReceived'] ?? 'File received!';
  String get openFiles => _localizedValues[locale.languageCode]?['openFiles'] ?? 'Open Files';
  String get openFileFailed => _localizedValues[locale.languageCode]?['openFileFailed'] ?? 'Failed to open file';
  String get openLocationFailed => _localizedValues[locale.languageCode]?['openLocationFailed'] ?? 'Failed to open location';
  String get filesDeletedCount => _localizedValues[locale.languageCode]?['filesDeletedCount'] ?? 'files deleted';
  String get noDevicesAvailable => _localizedValues[locale.languageCode]?['noDevicesAvailable'] ?? 'No devices available';
  String get filePickFailed => _localizedValues[locale.languageCode]?['filePickFailed'] ?? 'Failed to pick file';
  String get sendingFile => _localizedValues[locale.languageCode]?['sendingFile'] ?? 'Sending file to';
  String get fileSentSuccess => _localizedValues[locale.languageCode]?['fileSentSuccess'] ?? 'File sent successfully';
  String get fileSendFailed => _localizedValues[locale.languageCode]?['fileSendFailed'] ?? 'Failed to send file';
  String get selectDeviceFirst => _localizedValues[locale.languageCode]?['selectDeviceFirst'] ?? 'Select device first';
  String get chooseDevice => _localizedValues[locale.languageCode]?['chooseDevice'] ?? 'Choose Device';
  String get from => _localizedValues[locale.languageCode]?['from'] ?? 'From';
  String get savedIn => _localizedValues[locale.languageCode]?['savedIn'] ?? 'Saved in';
  String get filesTab => _localizedValues[locale.languageCode]?['filesTab'] ?? 'Files tab';
  String get receiving => _localizedValues[locale.languageCode]?['receiving'] ?? 'Receiving...';
  String get fileSize => _localizedValues[locale.languageCode]?['fileSize'] ?? 'File Size';
  String get contactUs => _localizedValues[locale.languageCode]?['contactUs'] ?? 'Contact Us';
  String get weAreHappyToHear => _localizedValues[locale.languageCode]?['weAreHappyToHear'] ?? 'We are happy to hear from you';
  String get yourName => _localizedValues[locale.languageCode]?['yourName'] ?? 'Name';
  String get email => _localizedValues[locale.languageCode]?['email'] ?? 'Email';
  String get category => _localizedValues[locale.languageCode]?['category'] ?? 'Category';
  String get subject => _localizedValues[locale.languageCode]?['subject'] ?? 'Subject';
  String get message => _localizedValues[locale.languageCode]?['message'] ?? 'Message';
  String get sending => _localizedValues[locale.languageCode]?['sending'] ?? 'Sending...';
  String get sendMessage => _localizedValues[locale.languageCode]?['sendMessage'] ?? 'Send';
  String get fieldRequired => _localizedValues[locale.languageCode]?['fieldRequired'] ?? 'This field is required';
  String get emailOpened => _localizedValues[locale.languageCode]?['emailOpened'] ?? 'Email app opened';
  String get inquiry => _localizedValues[locale.languageCode]?['inquiry'] ?? 'Inquiry';
  String get technicalIssue => _localizedValues[locale.languageCode]?['technicalIssue'] ?? 'Technical Issue';
  String get suggestion => _localizedValues[locale.languageCode]?['suggestion'] ?? 'Suggestion';
  String get other => _localizedValues[locale.languageCode]?['other'] ?? 'Other';
  String get aboutApp => _localizedValues[locale.languageCode]?['aboutApp'] ?? 'About App';
  String get appDescription => _localizedValues[locale.languageCode]?['appDescription'] ?? 'Fast and secure file sharing app';
  String get importantLinks => _localizedValues[locale.languageCode]?['importantLinks'] ?? 'Important Links';
  String get privacyPolicy => _localizedValues[locale.languageCode]?['privacyPolicy'] ?? 'Privacy Policy';
  String get termsOfService => _localizedValues[locale.languageCode]?['termsOfService'] ?? 'Terms of Service';
  String get legalInfo => _localizedValues[locale.languageCode]?['legalInfo'] ?? 'Legal Information';
  String get disclaimer => _localizedValues[locale.languageCode]?['disclaimer'] ?? 'Disclaimer';
  String get disclaimerText => _localizedValues[locale.languageCode]?['disclaimerText'] ?? 'This app is provided "as is" without any warranties.';
  String get copyright => _localizedValues[locale.languageCode]?['copyright'] ?? 'Copyright';
  String get copyrightText => _localizedValues[locale.languageCode]?['copyrightText'] ?? '© 2025 Apex Flow Group. All rights reserved.';
  String get madeInArabWorld => _localizedValues[locale.languageCode]?['madeInArabWorld'] ?? 'Made in the Arab World';
  String get pressMenuForSettings => _localizedValues[locale.languageCode]?['pressMenuForSettings'] ?? 'Press MENU for Settings';
  String get notConnectedToWiFi => _localizedValues[locale.languageCode]?['notConnectedToWiFi'] ?? 'Not Connected to WiFi';
  String get mustConnectToWiFi => _localizedValues[locale.languageCode]?['mustConnectToWiFi'] ?? 'You must connect to a WiFi network to use the app';
  String get openWiFiSettings => _localizedValues[locale.languageCode]?['openWiFiSettings'] ?? 'Open WiFi Settings';
  String get createHotspot => _localizedValues[locale.languageCode]?['createHotspot'] ?? 'Create Hotspot';
  String get music => _localizedValues[locale.languageCode]?['music'] ?? 'Music';
  String get songs => _localizedValues[locale.languageCode]?['songs'] ?? 'Songs';
  String get albums => _localizedValues[locale.languageCode]?['albums'] ?? 'Albums';
  String get artists => _localizedValues[locale.languageCode]?['artists'] ?? 'Artists';
  String get folders => _localizedValues[locale.languageCode]?['folders'] ?? 'Folders';
  String get noMusic => _localizedValues[locale.languageCode]?['noMusic'] ?? 'No music';
  String get noAlbums => _localizedValues[locale.languageCode]?['noAlbums'] ?? 'No albums';
  String get noArtists => _localizedValues[locale.languageCode]?['noArtists'] ?? 'No artists';
  String get searchMusic => _localizedValues[locale.languageCode]?['searchMusic'] ?? 'Search music...';
  String get playAll => _localizedValues[locale.languageCode]?['playAll'] ?? 'Play All';
  String get shuffle => _localizedValues[locale.languageCode]?['shuffle'] ?? 'Shuffle';
  String get addToQueue => _localizedValues[locale.languageCode]?['addToQueue'] ?? 'Add to Queue';
  String get songInfo => _localizedValues[locale.languageCode]?['songInfo'] ?? 'Song Info';
  String get selectFolder => _localizedValues[locale.languageCode]?['selectFolder'] ?? 'Select Folder';
  String get customFolder => _localizedValues[locale.languageCode]?['customFolder'] ?? 'Custom Folder';
  String get rescanLibrary => _localizedValues[locale.languageCode]?['rescanLibrary'] ?? 'Rescan Library';
  String get defaultFolders => _localizedValues[locale.languageCode]?['defaultFolders'] ?? 'Default Folders';
  String get enterPath => _localizedValues[locale.languageCode]?['enterPath'] ?? 'Enter folder path:';
  String get examples => _localizedValues[locale.languageCode]?['examples'] ?? 'Examples:';
  String get tipCopyPath => _localizedValues[locale.languageCode]?['tipCopyPath'] ?? 'Tip: Copy path from file manager';
  String get scanFailed => _localizedValues[locale.languageCode]?['scanFailed'] ?? 'Scan failed';
  String get play => _localizedValues[locale.languageCode]?['play'] ?? 'Play';
  String get pause => _localizedValues[locale.languageCode]?['pause'] ?? 'Pause';
  String get previous => _localizedValues[locale.languageCode]?['previous'] ?? 'Previous';
  String get queue => _localizedValues[locale.languageCode]?['queue'] ?? 'Queue';
  String get nowPlaying => _localizedValues[locale.languageCode]?['nowPlaying'] ?? 'Now Playing';
  String get unknownArtist => _localizedValues[locale.languageCode]?['unknownArtist'] ?? 'Unknown Artist';
  String get unknownAlbum => _localizedValues[locale.languageCode]?['unknownAlbum'] ?? 'Unknown Album';
  String get track => _localizedValues[locale.languageCode]?['track'] ?? 'Track';
  String get tracks => _localizedValues[locale.languageCode]?['tracks'] ?? 'Tracks';
  String get album => _localizedValues[locale.languageCode]?['album'] ?? 'Album';
  String get artist => _localizedValues[locale.languageCode]?['artist'] ?? 'Artist';
  String get duration => _localizedValues[locale.languageCode]?['duration'] ?? 'Duration';
  String get path => _localizedValues[locale.languageCode]?['path'] ?? 'Path';
  String get addedToQueue => _localizedValues[locale.languageCode]?['addedToQueue'] ?? 'Added to queue';
  String get exitApp => _localizedValues[locale.languageCode]?['exitApp'] ?? 'Exit App';
  String get exitConfirmation => _localizedValues[locale.languageCode]?['exitConfirmation'] ?? 'Do you want to exit the app?';
  String get exit => _localizedValues[locale.languageCode]?['exit'] ?? 'Exit';
  String get availableDevices => _localizedValues[locale.languageCode]?['availableDevices'] ?? 'Available Devices';
  String get pickFile => _localizedValues[locale.languageCode]?['pickFile'] ?? 'Pick File';
  String get systemNotRunning => _localizedValues[locale.languageCode]?['systemNotRunning'] ?? 'System not running';
  String get fileSentSuccessfully => _localizedValues[locale.languageCode]?['fileSentSuccessfully'] ?? 'File sent successfully';
  String foundSongs(int count) => _localizedValues[locale.languageCode]?['foundSongs']?.replaceAll('{count}', count.toString()) ?? 'Found $count songs';
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

