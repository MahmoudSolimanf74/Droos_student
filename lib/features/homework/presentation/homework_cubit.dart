import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/homework_repository.dart';

abstract class HomeworkState extends Equatable {
  const HomeworkState();
  @override
  List<Object?> get props => [];
}

class HomeworkInitial extends HomeworkState {}
class HomeworkLoading extends HomeworkState {}
class HomeworkLoaded extends HomeworkState {
  final List<HomeworkRecordModel> records;
  const HomeworkLoaded(this.records);
  @override
  List<Object?> get props => [records];
}
class HomeworkError extends HomeworkState {
  final String message;
  const HomeworkError(this.message);
  @override
  List<Object?> get props => [message];
}

class HomeworkCubit extends Cubit<HomeworkState> {
  final HomeworkRepository _repository;

  HomeworkCubit({required HomeworkRepository repository})
      : _repository = repository,
        super(HomeworkInitial());

  Future<void> loadHomework(String studentId, {String? gradeId}) async {
    emit(HomeworkLoading());
    try {
      final records = await _repository.getMyHomework(studentId, gradeId: gradeId);
      emit(HomeworkLoaded(records));
    } catch (e) {
      emit(HomeworkError(e.toString()));
    }
  }

  Future<Set<String>> getSolvedHomeworks(String studentId) =>
      _repository.getSolvedHomeworks(studentId);

  Future<void> toggleSolvedHomework(String studentId, String homeworkId) =>
      _repository.toggleSolvedHomework(studentId, homeworkId);
}
