import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/attendance_repository.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();
  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}
class AttendanceLoading extends AttendanceState {}
class AttendanceLoaded extends AttendanceState {
  final List<AttendanceRecordModel> records;
  const AttendanceLoaded(this.records);
  @override
  List<Object?> get props => [records];
}
class AttendanceError extends AttendanceState {
  final String message;
  const AttendanceError(this.message);
  @override
  List<Object?> get props => [message];
}

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceCubit({required AttendanceRepository repository})
      : _repository = repository,
        super(AttendanceInitial());

  Future<void> loadAttendance(String studentId, {String? gradeId}) async {
    emit(AttendanceLoading());
    try {
      final records = await _repository.getMyAttendance(studentId, gradeId: gradeId);
      emit(AttendanceLoaded(records));
    } catch (e) {
      emit(AttendanceError(e.toString()));
    }
  }

  Future<Set<String>> getStudiedLessons(String studentId) =>
      _repository.getStudiedLessons(studentId);

  Future<void> toggleStudiedLesson(String studentId, String sessionId) =>
      _repository.toggleStudiedLesson(studentId, sessionId);
}
