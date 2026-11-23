import 'dart:async';
import 'api_client.dart';
import 'document_store.dart';

class UserInfo {
  final String providerId = 'password';
}

class MfaRequired implements Exception {
  final String challenge;
  const MfaRequired(this.challenge);
}

class User {
  final String uid;
  final String email;
  User(this.uid, this.email);
  List<UserInfo> get providerData => [UserInfo()];
}

class LocalAuth {
  static final instance = LocalAuth._();
  LocalAuth._();
  final _changes = StreamController<User?>.broadcast();
  final _expired = StreamController<void>.broadcast();
  Timer? _expiryTimer;
  DateTime? _expiresAt;
  User? currentUser;

  Stream<void> get sessionExpired => _expired.stream;

  void checkExpiry() {
    _expiryTimer?.cancel();
    final expiresAt = _expiresAt;
    if (currentUser == null || expiresAt == null) return;
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _accept({'user': null});
      _expired.add(null);
    } else {
      const maxDelay = Duration(days: 1);
      _expiryTimer = Timer(
        remaining < maxDelay ? remaining : maxDelay,
        checkExpiry,
      );
    }
  }

  Future<void> initialize() async {
    final response = await ApiClient.instance.request('auth/session');
    _accept(response);
  }

  void _accept(Map<String, dynamic> response) {
    final value = response['user'];
    currentUser = value == null ? null : User(value['uid'], value['email']);
    _expiresAt = DateTime.tryParse(response['expiresAt']?.toString() ?? '');
    DocumentStore.instance.clear();
    _changes.add(currentUser);
    checkExpiry();
  }

  Stream<User?> authStateChanges() async* {
    yield currentUser;
    yield* _changes.stream;
  }

  Future<User> authenticate(String action, Map<String, dynamic> data) async {
    final result = await ApiClient.instance.request('auth/$action', data);
    if (result['mfa_required'] == true) {
      throw MfaRequired(result['challenge'] as String);
    }
    _accept(result);
    return currentUser!;
  }

  Future<void> signOut() async {
    await ApiClient.instance.request('auth/logout', {});
    _accept({'user': null});
  }

  Future<void> deleteAccount() async {
    await ApiClient.instance.request('auth/delete', {});
    _accept({'user': null});
  }
}
