import '../models/json_values.dart';
import 'role.dart';

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final Role role;
  final String? clientId;
  final String? masterId;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.clientId,
    this.masterId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: asString(json['id']),
    email: asString(json['email']),
    fullName: asString(json['name'] ?? json['fullName']),
    role: Role.parse(json['role']),
    clientId: asStringOrNull(json['client'] ?? json['clientId']),
    masterId: asStringOrNull(json['master'] ?? json['masterId']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': fullName,
    'role': role.apiName,
    'client': clientId,
    'master': masterId,
  };

  String get displayName => fullName.isEmpty ? email : fullName;

  AppUser copyWith({Role? role}) => AppUser(
    id: id,
    email: email,
    fullName: fullName,
    role: role ?? this.role,
    clientId: clientId,
    masterId: masterId,
  );
}
