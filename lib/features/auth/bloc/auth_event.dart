abstract class AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested({required this.email, required this.password});
}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String phone;
  final String password;
  final String role;
  AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
  });
}

class AuthGoogleLoginRequested extends AuthEvent {}

class AuthLogoutRequested extends AuthEvent {}

class AuthCheckRequested extends AuthEvent {}
