import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_emulators.dart';

/// Wraps Firebase Authentication and Google Sign-In.
///
/// This is the only place in the app that talks to these SDKs directly;
/// everything else goes through [authStateChanges] or the methods below.
///
/// On the web (a development build only, MANUAL 42) Google sign-in is a
/// Firebase popup instead: the google_sign_in package's flow is for phones.
class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Web (type 3) OAuth client ID from android/app/google-services.json.
  // Required on Android by google_sign_in v7+ even though it's a "web" ID.
  static const _serverClientId =
      '227856433742-ou8hlre73l6209895a5vkkjqltcc2rq7.apps.googleusercontent.com';

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize(serverClientId: _serverClientId);
    _googleSignInInitialized = true;
  }

  Future<AuthCredential> _googleCredential() async {
    await _ensureGoogleSignInInitialized();
    final GoogleSignInAccount account = await _googleSignIn.authenticate();
    return GoogleAuthProvider.credential(
        idToken: account.authentication.idToken);
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      return FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    }
    return FirebaseAuth.instance.signInWithCredential(await _googleCredential());
  }

  /// Signs in as a made-up Google user — only against the Auth emulator
  /// (MANUAL 42), which accepts an unsigned token. The real service would
  /// refuse it. Same [name], same user, so a test can come back as them.
  Future<UserCredential> signInAsTestUser(String name) {
    assert(useEmulators, 'Test users only exist on the emulators');
    return FirebaseAuth.instance
        .signInWithCredential(_testUserCredential('test-$name', name));
  }

  static AuthCredential _testUserCredential(String sub, String name) =>
      GoogleAuthProvider.credential(
        idToken: jsonEncode({
          'sub': sub,
          'email': '$name@example.com',
          'email_verified': true,
          'name': name,
        }),
      );

  /// Has the user sign in with Google again, for something Firebase only
  /// allows right after signing in — deleting the account.
  Future<void> reauthenticateWithGoogle() async {
    final user = currentUser;
    if (user == null) throw StateError('ログインしていません');
    if (useEmulators) {
      final google =
          user.providerData.firstWhere((p) => p.providerId == 'google.com');
      await user.reauthenticateWithCredential(_testUserCredential(
          google.uid!, (google.email ?? '').split('@').first));
      return;
    }
    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return;
    }
    await user.reauthenticateWithCredential(await _googleCredential());
  }

  /// Removes the Firebase account itself and signs out of Google, which
  /// takes the app back to the sign-in screen.
  Future<void> deleteCurrentUser() async {
    await currentUser?.delete();
    if (!kIsWeb) await _googleSignIn.signOut();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb) await _googleSignIn.signOut();
  }
}
