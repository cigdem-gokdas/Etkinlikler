class OtpConfig {
  const OtpConfig({this.length = defaultLength});

  static const defaultLength = int.fromEnvironment(
    'OTP_LENGTH',
    defaultValue: 6,
  );
  final int length;

  String? get problem =>
      length == 6 || length == 8 ? null : 'OTP_LENGTH ayarı 6 veya 8 olmalı.';

  bool accepts(String code) =>
      problem == null &&
      code.length == length &&
      RegExp(r'^[0-9]+$').hasMatch(code);
}
