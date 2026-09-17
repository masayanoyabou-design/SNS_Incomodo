import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Points the app at Firebase emulators running on this computer instead of
/// the real project — for trying the web build without real Google accounts
/// or real data (MANUAL 42).
///
///   flutter run -d web-server --dart-define=USE_EMULATORS=true
///
/// Off unless asked for, so no normal build can end up talking to them.
const useEmulators = bool.fromEnvironment('USE_EMULATORS');

Future<void> connectToEmulators() async {
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
}
