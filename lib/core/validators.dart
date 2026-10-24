/// Form validators (CLAUDE.md section 11).
///
/// Each returns `null` when the value is valid, or a user-facing message.
/// They match the `FormFieldValidator<String>` signature so they can be
/// passed straight to `TextFormField.validator`.
abstract final class Validators {
  static const maxEmailLength = 254;
  static const otpLength = 6;
  static const minNameLength = 2;
  static const maxNameLength = 50;
  static const minAddressLength = 5;
  static const minPrice = 1;
  static const maxPrice = 5000;
  static const maxChatLength = 300;
  static const minQuantity = 1;
  static const maxQuantity = 10;
  static const quantityMessage =
      'Quantity must be between $minQuantity and $maxQuantity';

  static final _email = RegExp(
    r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*"
    r'@([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$',
  );
  static final _otp = RegExp(r'^\d{6}$');
  // Letters plus combining marks (Indian scripts), spaces, hyphens, dots and
  // straight or curly apostrophes, so D'Souza and Anne-Marie pass.
  static final _name = RegExp(r"^[\p{L}\p{M} .'’-]+$", unicode: true);
  static final _hasLetter = RegExp(r'\p{L}', unicode: true);
  static final _indianMobile = RegExp(r'^[6-9]\d{9}$');
  static final _wholeNumber = RegExp(r'^\d+$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address';
    if (email.length > maxEmailLength || !_email.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? otp(String? value) {
    final code = value?.trim() ?? '';
    if (!_otp.hasMatch(code)) return 'Enter the 6-digit code';
    return null;
  }

  static String? fullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your name';
    if (name.length < minNameLength || name.length > maxNameLength) {
      return 'Name must be $minNameLength-$maxNameLength characters';
    }
    if (!_name.hasMatch(name) || !_hasLetter.hasMatch(name)) {
      return 'Use letters, spaces, hyphens, dots and apostrophes only';
    }
    return null;
  }

  /// Strips spaces, dashes and a leading +91 / 91 / 0, leaving 10 digits
  /// when the input is a valid Indian mobile number.
  static String normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'[\s-]'), '');
    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  static String? phone(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Enter your mobile number';
    if (!_indianMobile.hasMatch(normalizePhone(raw))) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  static String? addressLine(String? value) {
    final line = value?.trim() ?? '';
    if (line.length < minAddressLength) return 'Enter your delivery address';
    return null;
  }

  /// Optional: empty means "no price cap".
  /// Chat message: trimmed, required, at most [maxChatLength] characters.
  static String? chatMessage(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return "Tell me how you feel or what you're craving";
    if (text.length > maxChatLength) return 'Keep it under $maxChatLength characters';
    return null;
  }

  static String? maxPriceInr(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (parseMaxPrice(text) == null) {
      return 'Enter a price between $minPrice and $maxPrice';
    }
    return null;
  }

  /// Parsed price cap, or `null` for empty or invalid input.
  static int? parseMaxPrice(String? value) {
    final text = value?.trim() ?? '';
    if (!_wholeNumber.hasMatch(text) || text.length > 4) return null;
    final price = int.parse(text);
    return price >= minPrice && price <= maxPrice ? price : null;
  }

  static String? quantity(int value) {
    if (value < minQuantity || value > maxQuantity) return quantityMessage;
    return null;
  }
}
