import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptionsIOS {
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR-IOS-API-KEY',
    appId: 'YOUR-IOS-APP-ID',
    messagingSenderId: 'YOUR-IOS-SENDER-ID',
    projectId: 'YOUR-IOS-PROJECT-ID',
    storageBucket: 'YOUR-IOS-STORAGE-BUCKET',
    iosClientId: 'YOUR-IOS-CLIENT-ID',
    iosBundleId: 'YOUR-IOS-BUNDLE-ID',
  );
} 