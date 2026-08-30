import 'package:equatable/equatable.dart';

class StudentGroupEnrollment extends Equatable {
  final String studentRecordId;
  final String gradeId;
  final String gradeName;
  final String teacherId;
  final String teacherName;

  const StudentGroupEnrollment({
    required this.studentRecordId,
    required this.gradeId,
    required this.gradeName,
    required this.teacherId,
    required this.teacherName,
  });

  factory StudentGroupEnrollment.fromJson(Map<String, dynamic> json) => StudentGroupEnrollment(
        studentRecordId: json['studentRecordId']?.toString() ?? json['id']?.toString() ?? '',
        gradeId: json['gradeId']?.toString() ?? json['grade_id']?.toString() ?? '',
        gradeName: json['gradeName']?.toString() ?? json['grade_name']?.toString() ?? 'المجموعة الدراسية',
        teacherId: json['teacherId']?.toString() ?? json['teacher_id']?.toString() ?? '',
        teacherName: json['teacherName']?.toString() ?? json['teacher_name']?.toString() ?? 'المعلم',
      );

  Map<String, dynamic> toJson() => {
        'studentRecordId': studentRecordId,
        'gradeId': gradeId,
        'gradeName': gradeName,
        'teacherId': teacherId,
        'teacherName': teacherName,
      };

  @override
  List<Object?> get props => [studentRecordId, gradeId, gradeName, teacherId, teacherName];
}

class StudentProfileModel extends Equatable {
  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String parentPhone;
  final String? gradeId;
  final String? gradeName;
  final String? teacherId;
  final String? teacherName;
  final List<StudentGroupEnrollment> enrollments;

  const StudentProfileModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.parentPhone,
    this.gradeId,
    this.gradeName,
    this.teacherId,
    this.teacherName,
    this.enrollments = const [],
  });

  bool get isProfileComplete => fullName.isNotEmpty && phone.isNotEmpty && parentPhone.isNotEmpty;
  bool get isEnrolledInGroup => (gradeId != null && gradeId!.isNotEmpty) || enrollments.isNotEmpty;

  StudentProfileModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? phone,
    String? parentPhone,
    String? gradeId,
    String? gradeName,
    String? teacherId,
    String? teacherName,
    List<StudentGroupEnrollment>? enrollments,
  }) {
    return StudentProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      parentPhone: parentPhone ?? this.parentPhone,
      gradeId: gradeId ?? this.gradeId,
      gradeName: gradeName ?? this.gradeName,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      enrollments: enrollments ?? this.enrollments,
    );
  }

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    final grade = json['grades'] as Map<String, dynamic>?;
    final teacher = json['profiles'] as Map<String, dynamic>?;

    final name = json['fullName'] as String? ?? json['name'] as String? ?? json['full_name'] as String? ?? '';
    final uId = json['userId'] as String? ?? json['profile_id'] as String? ?? json['user_id'] as String? ?? '';
    final gName = json['gradeName'] as String? ?? json['grade_name'] as String? ?? (grade != null ? grade['name'] as String? : null);
    final tName = json['teacherName'] as String? ?? json['teacher_name'] as String? ?? (teacher != null ? (teacher['name'] as String? ?? teacher['full_name'] as String?) : null);

    List<StudentGroupEnrollment> parsedEnrollments = [];
    if (json['enrollments'] is List) {
      parsedEnrollments = (json['enrollments'] as List)
          .map((e) => StudentGroupEnrollment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return StudentProfileModel(
      id: json['id'] as String? ?? '',
      userId: uId,
      fullName: name,
      phone: json['phone'] as String? ?? '',
      parentPhone: json['parent_phone'] as String? ?? json['parentPhone'] as String? ?? '',
      gradeId: json['grade_id'] as String? ?? json['gradeId'] as String?,
      gradeName: gName,
      teacherId: json['teacher_id'] as String? ?? json['teacherId'] as String?,
      teacherName: tName,
      enrollments: parsedEnrollments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'fullName': fullName,
        'phone': phone,
        'parentPhone': parentPhone,
        'gradeId': gradeId,
        'gradeName': gradeName,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'enrollments': enrollments.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [id, userId, fullName, phone, parentPhone, gradeId, gradeName, teacherId, teacherName, enrollments];
}
