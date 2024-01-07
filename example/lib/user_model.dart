class UserModel {
  UserModel({
    this.userId,
    this.firstName,
    this.email,
  });

  int userId;
  String firstName;
  String email;

  UserModel.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'] as int ?? 0;
    firstName = json['first_name'] as String;
    email = json['email'] as String;
  }
}
