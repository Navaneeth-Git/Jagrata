import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptionsWeb {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR-ACTUAL-API-KEY',
    appId: 'YOUR-ACTUAL-APP-ID',
    messagingSenderId: 'YOUR-ACTUAL-SENDER-ID',
    projectId: 'YOUR-ACTUAL-PROJECT-ID',
    authDomain: 'YOUR-ACTUAL-AUTH-DOMAIN',
    storageBucket: 'YOUR-ACTUAL-STORAGE-BUCKET',
  );
} 