import 'package:equatable/equatable.dart';
import '../domain/student_profile_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Unauthenticated extends AuthState {}

class ProfileIncomplete extends AuthState {
  final StudentProfileModel profile;
  const ProfileIncomplete(this.profile);
  @override
  List<Object?> get props => [profile];
}

class Authenticated extends AuthState {
  final StudentProfileModel profile;
  const Authenticated(this.profile);
  @override
  List<Object?> get props => [profile];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}
