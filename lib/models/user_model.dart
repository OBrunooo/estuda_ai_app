/// Usuário autenticado no backend Laravel.
///
/// `POST /api/login` e `POST /api/registrar` retornam o objeto `User`
/// serializado pelo Eloquent (sem `password`/`remember_token`), com os campos:
/// `id, name, email, email_verified_at, avatar_id, created_at, updated_at`.
class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarId,
    this.emailVerifiedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is int
        ? idRaw
        : idRaw is num
            ? idRaw.toInt()
            : int.parse(idRaw.toString());

    final avatarRaw = json['avatar_id'] ?? json['avatarId'];
    int? avatarId;
    if (avatarRaw is int) {
      avatarId = avatarRaw;
    } else if (avatarRaw is num) {
      avatarId = avatarRaw.toInt();
    } else if (avatarRaw != null) {
      avatarId = int.tryParse(avatarRaw.toString());
    }

    final verifRaw = json['email_verified_at'] ?? json['emailVerifiedAt'];
    DateTime? verifiedAt;
    if (verifRaw is String && verifRaw.isNotEmpty) {
      verifiedAt = DateTime.tryParse(verifRaw);
    }

    return UserModel(
      id: id,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      avatarId: avatarId,
      emailVerifiedAt: verifiedAt,
    );
  }

  final int id;
  final String name;
  final String email;

  /// `users.avatar_id` (int) — atualmente não há endpoint para escrever
  /// (ver `PENDENCIAS_BACKEND.md`). O Flutter ignora este valor enquanto isso.
  final int? avatarId;

  final DateTime? emailVerifiedAt;

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    int? avatarId,
    DateTime? emailVerifiedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarId: avatarId ?? this.avatarId,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
    );
  }
}
