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

/// Where to pretend to be, from the page address, e.g.
/// `http://localhost:5173/?at=35.6812,139.7671` — emulator builds only.
/// A browser pane may not share its location, and moving is the point of
/// the app, so tests set it by hand.
({double latitude, double longitude})? testLocation() {
  if (!useEmulators) return null;
  final parts = Uri.base.queryParameters['at']?.split(',');
  if (parts == null || parts.length != 2) return null;
  final latitude = double.tryParse(parts[0]);
  final longitude = double.tryParse(parts[1]);
  if (latitude == null || longitude == null) return null;
  return (latitude: latitude, longitude: longitude);
}

Future<void> connectToEmulators() async {
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
}
