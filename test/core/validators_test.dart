import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/core/validators.dart';

void main() {
  group('email', () {
    test('accepts a valid address, trimming spaces', () {
      expect(Validators.email('  user.name+tag@example.co.in '), isNull);
    });
    test('rejects empty', () {
      expect(Validators.email(''), 'Enter your email address');
      expect(Validators.email(null), 'Enter your email address');
      expect(Validators.email('   '), 'Enter your email address');
    });
    test('rejects bad formats', () {
      for (final bad in ['plainaddress', 'a@b', 'a@b.c', '@example.com', 'a..b@example.com', 'a@-example.com', 'a b@example.com']) {
        expect(Validators.email(bad), 'Enter a valid email address', reason: bad);
      }
    });
    test('rejects addresses longer than 254 characters', () {
      final long = '${'a' * 64}@${'b' * 186}.com';
      expect(long.length, greaterThan(254));
      expect(Validators.email(long), 'Enter a valid email address');
    });
  });

  group('otp', () {
    test('accepts exactly 6 digits', () {
      expect(Validators.otp('123456'), isNull);
      expect(Validators.otp(' 012345 '), isNull);
    });
    test('rejects wrong length, letters and empty', () {
      for (final bad in ['', '12345', '1234567', '12a456', '12 456', null]) {
        expect(Validators.otp(bad), 'Enter the 6-digit code', reason: '$bad');
      }
    });
  });

  group('fullName', () {
    const nameCharsMessage =
        'Use letters, spaces, hyphens, dots and apostrophes only';
    test('accepts letters, spaces, hyphens, dots and apostrophes', () {
      expect(Validators.fullName('Ishaan Patel'), isNull);
      expect(Validators.fullName('Jo'), isNull);
      expect(Validators.fullName('प्रिया शर्मा'), isNull);
      expect(Validators.fullName('Anne-Marie'), isNull);
      expect(Validators.fullName("D'Souza"), isNull);
      expect(Validators.fullName('D’Souza'), isNull);
      expect(Validators.fullName('J. R. Tolkien'), isNull);
    });
    test('rejects empty, too short, too long and symbols', () {
      expect(Validators.fullName(''), 'Enter your name');
      expect(Validators.fullName('A'), 'Name must be 2-50 characters');
      expect(Validators.fullName('A' * 51), 'Name must be 2-50 characters');
      expect(Validators.fullName('R2D2'), nameCharsMessage);
      expect(Validators.fullName('Anne_Marie'), nameCharsMessage);
      expect(Validators.fullName('---'), nameCharsMessage);
      expect(Validators.fullName('..'), nameCharsMessage);
    });
  });

  group('phone', () {
    test('accepts Indian mobile numbers in common formats', () {
      for (final ok in ['9876543210', '+91 98765 43210', '+919876543210', '919876543210', '09876543210', '98765-43210']) {
        expect(Validators.phone(ok), isNull, reason: ok);
      }
    });
    test('normalizes to 10 digits', () {
      expect(Validators.normalizePhone('+91 98765 43210'), '9876543210');
      expect(Validators.normalizePhone('09876543210'), '9876543210');
    });
    test('rejects invalid numbers', () {
      expect(Validators.phone(''), 'Enter your mobile number');
      for (final bad in ['5876543210', '987654321', '98765432101', '98765abcde']) {
        expect(Validators.phone(bad), 'Enter a valid 10-digit mobile number', reason: bad);
      }
    });
  });

  group('addressLine', () {
    test('requires at least 5 characters after trimming', () {
      expect(Validators.addressLine('12 Hill Road'), isNull);
      expect(Validators.addressLine('  ab  '), 'Enter your delivery address');
      expect(Validators.addressLine(null), 'Enter your delivery address');
    });
  });

  group('max price', () {
    test('empty means no cap', () {
      expect(Validators.maxPriceInr(''), isNull);
      expect(Validators.parseMaxPrice(''), isNull);
    });
    test('accepts whole numbers 1-5000', () {
      expect(Validators.maxPriceInr('1'), isNull);
      expect(Validators.maxPriceInr('5000'), isNull);
      expect(Validators.parseMaxPrice(' 250 '), 250);
    });
    test('rejects out of range and non-numbers', () {
      for (final bad in ['0', '5001', '-5', '12.5', 'abc', '99999999999']) {
        expect(Validators.maxPriceInr(bad), 'Enter a price between 1 and 5000', reason: bad);
      }
    });
  });

  group('quantity', () {
    test('allows 1-10 only', () {
      expect(Validators.quantity(1), isNull);
      expect(Validators.quantity(10), isNull);
      expect(Validators.quantity(0), 'Quantity must be between 1 and 10');
      expect(Validators.quantity(11), 'Quantity must be between 1 and 10');
    });
  });
}
