import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/auth_repository.dart';
import '../models/user_model.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;

  AuthBloc({required AuthRepository authRepository})
      : _repo = authRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheck(AuthCheckRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final user = await _repo.getSavedUser();
    if (user != null) {
      emit(AuthAuthenticated(user: user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _repo.login(email: e.email, password: e.password);
    if (result['success']) {
      emit(AuthAuthenticated(user: UserModel.fromJson(result['user'])));
    } else {
      emit(AuthError(message: result['message']));
    }
  }

  Future<void> _onRegister(AuthRegisterRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _repo.register(
      name: e.name, email: e.email,
      phone: e.phone, password: e.password, role: e.role,
    );
    if (result['success']) {
      emit(AuthAuthenticated(user: UserModel.fromJson(result['user'])));
    } else {
      emit(AuthError(message: result['message']));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested e, Emitter<AuthState> emit) async {
    await _repo.logout();
    emit(AuthUnauthenticated());
  }
}
