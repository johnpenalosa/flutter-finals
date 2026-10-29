String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
    return 'Invalid email';
  }
  return null;
}

String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'Enter your password';
  if (v.length < 8) return 'At least 8 characters';
  if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Must include an uppercase letter (A-Z)';
  if (!RegExp(r'[a-z]').hasMatch(v)) return 'Must include a lowercase letter (a-z)';
  if (!RegExp(r'[0-9]').hasMatch(v)) return 'Must include a number';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
    return 'Must include a special character (!@#\$ etc)';
  }
  return null;
}