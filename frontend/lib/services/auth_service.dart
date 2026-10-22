import 'package:mysold/data/api_client.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:mysold/services/app_logger.dart';

class AuthService {
  final _auth = LocalAuth.instance;
  Stream<User?> get userChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  Future<void> updateLastConnection(User user) async {}

  Future<User?> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> additionalData,
  }) async {
    try {
      return await _auth.authenticate('register', {
        'email': email,
        'password': password,
        'profile': encodeValue(additionalData),
      });
    } catch (e) {
      AppLogger.error('Registration failed', error: e);
      return null;
    }
  }

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.authenticate('login', {
        'email': email,
        'password': password,
      });
    } catch (e) {
      AppLogger.error('Login failed', error: e);
      return null;
    }
  }

  Future<bool> reauthenticateForAccountDeletion({String? password}) async {
    try {
      await ApiClient.instance.request('auth/reauthenticate', {
        'password': password,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCurrentAuthUser() async {
    try {
      await _auth.deleteAccount();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() => _auth.signOut();
}
