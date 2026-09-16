import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps Firebase Authentication and Google Sign-In.
///
/// This is the only place in the app that talks to these SDKs directly;
/// everything else goes through [authStateChanges] or the methods below.
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

  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();
    final GoogleSignInAccount account = await _googleSignIn.authenticate();
    final String? idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  /// Has the user sign in with Google again, for something Firebase only
  /// allows right after signing in — deleting the account.
  Future<void> reauthenticateWithGoogle() async {
    final user = currentUser;
    if (user == null) throw StateError('ログインしていません');
    await _ensureGoogleSignInInitialized();
    final account = await _googleSignIn.authenticate();
    final credential =
        GoogleAuthProvider.credential(idToken: account.authentication.idToken);
    await user.reauthenticateWithCredential(credential);
  }

  /// Removes the Firebase account itself and signs out of Google, which
  /// takes the app back to the sign-in screen.
  Future<void> deleteCurrentUser() async {
    await currentUser?.delete();
    await _googleSignIn.signOut();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
  }
}
