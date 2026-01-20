import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';

class AuthController {
  AuthController(this._repository);

  final AuthRepository _repository;

  Future<void> signIn(String email, String password) {
    return _repository.signIn(email, password);
  }

  Future<void> signUp(String email, String password) {
    return _repository.signUp(email, password);
  }

  Future<void> signOut() {
    return _repository.signOut();
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
