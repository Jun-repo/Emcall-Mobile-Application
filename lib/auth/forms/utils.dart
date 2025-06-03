String getFullName({
  required String firstName,
  String? middleName,
  required String lastName,
  String? suffix,
}) {
  String fullName = firstName;
  if (middleName != null && middleName.isNotEmpty) {
    fullName += ' ${middleName[0]}.';
  }
  fullName += ' $lastName';
  if (suffix != null && suffix.isNotEmpty) {
    fullName += ' $suffix';
  }
  return fullName;
}
