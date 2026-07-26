// lib/data/models/department_model.dart

import '../../domain/entities/catalogue.dart';

class DepartmentModel {
  final String id;
  final String departmentId;
  final String departmentName;
  final String imageLink;
  final int sequenceId;
  bool isSelected;

  DepartmentModel({
    required this.id,
    required this.departmentId,
    required this.departmentName,
    required this.imageLink,
    required this.sequenceId,
    this.isSelected = false,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      departmentId: (json['department_id'] ?? '').toString(),
      departmentName: json['department_name'] ?? '',
      imageLink: json['image_link'] ?? '',
      sequenceId: json['sequence_id'] is int
          ? json['sequence_id']
          : int.tryParse(json['sequence_id']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'department_id': departmentId,
      'department_name': departmentName,
      'image_link': imageLink,
      'sequence_id': sequenceId,
    };
  }

  DepartmentModel copyWith({
    String? id,
    String? departmentId,
    String? departmentName,
    String? imageLink,
    int? sequenceId,
    bool? isSelected,
  }) {
    return DepartmentModel(
      id: id ?? this.id,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      imageLink: imageLink ?? this.imageLink,
      sequenceId: sequenceId ?? this.sequenceId,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  /// Converts to the domain entity.
  ///
  /// `isSelected` is deliberately not carried across: it is UI selection state
  /// and has no place on a shared entity.
  Department toEntity() => Department(
        id: id,
        code: departmentId,
        name: departmentName,
        imageUrl: imageLink,
        sequence: sequenceId,
      );
}
