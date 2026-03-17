class EmployeeModel {
  String? id;
  final String? name;
  final String? email;
  final String? phone;
  final String role; // (staff, supervisor, media buyer ...)
  final String? department;
  final String? fcmToken;
  final String? onesignal;
  final DateTime? hireDate;
  final String? status;
  final DateTime createdAt;
  final String? password; // اختياري مؤقتاً حتى لا نكسر البيانات القديمة
  final String? image; // 👈 تمت إضافة الصورة

  EmployeeModel({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.department,
    this.fcmToken,
    this.onesignal,
    this.hireDate,
    required this.status,
    required this.createdAt,
    this.password,
    this.image, // 👈
  });

  EmployeeModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? department,
    String? fcmToken,
    String? onesignal,
    DateTime? hireDate,
    String? status,
    DateTime? createdAt,
    String? password,
    String? image, // 👈
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      department: department ?? this.department,
      fcmToken: fcmToken ?? this.fcmToken,
      onesignal: onesignal ?? this.onesignal,
      hireDate: hireDate ?? this.hireDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      password: password ?? this.password,
      image: image ?? this.image, // 👈
    );
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      department: json['department'],
      fcmToken: json['fcmToken'],
      onesignal: json['onesignal'],
      hireDate:
          json['hireDate'] != null ? DateTime.parse(json['hireDate']) : null,
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      password: json['password'],
      image: json['image'], // 👈
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "phone": phone,
      "role": role,
      "department": department,
      "fcmToken": fcmToken,
      'onesignal': onesignal,
      "hireDate": hireDate?.toIso8601String(),
      "status": status,
      "createdAt": createdAt.toIso8601String(),
      if (password != null) "password": password,
      "image": image, // 👈
    };
  }
}
