// SharedCal model tests — AppUser, NotificationType
//
// Run with: flutter test test/models_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_cal/models/user.dart';

void main() {
  // ── NotificationType ────────────────────────────────────────────────────────

  group('NotificationType', () {
    group('fromApi', () {
      test('maps "push" to push', () {
        expect(NotificationType.fromApi('push'), NotificationType.push);
      });

      test('maps "email" to email', () {
        expect(NotificationType.fromApi('email'), NotificationType.email);
      });

      test('defaults to email for null', () {
        expect(NotificationType.fromApi(null), NotificationType.email);
      });

      test('defaults to email for unknown value', () {
        expect(NotificationType.fromApi('sms'), NotificationType.email);
        expect(NotificationType.fromApi(''), NotificationType.email);
      });
    });

    group('apiValue', () {
      test('email returns "email"', () {
        expect(NotificationType.email.apiValue, 'email');
      });

      test('push returns "push"', () {
        expect(NotificationType.push.apiValue, 'push');
      });
    });
  });

  // ── AppUser ─────────────────────────────────────────────────────────────────

  group('AppUser.fromJson', () {
    final baseJson = <String, dynamic>{
      'id': 'user-uuid-1',
      'email': 'alice@example.com',
      'name': 'Alice',
      'color': '#43B89C',
      'email_verified': true,
      'has_google_calendar': true,
      'notification_type': 'push',
    };

    test('parses all fields correctly', () {
      final user = AppUser.fromJson(baseJson);
      expect(user.id, 'user-uuid-1');
      expect(user.email, 'alice@example.com');
      expect(user.name, 'Alice');
      expect(user.color, '#43B89C');
      expect(user.emailVerified, isTrue);
      expect(user.hasGoogleCalendar, isTrue);
      expect(user.notificationType, NotificationType.push);
    });

    test('defaults emailVerified to false when absent', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..remove('email_verified');
      final user = AppUser.fromJson(json);
      expect(user.emailVerified, isFalse);
    });

    test('defaults hasGoogleCalendar to false when absent', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..remove('has_google_calendar');
      final user = AppUser.fromJson(json);
      expect(user.hasGoogleCalendar, isFalse);
    });

    test('defaults notificationType to email when absent', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..remove('notification_type');
      final user = AppUser.fromJson(json);
      expect(user.notificationType, NotificationType.email);
    });

    test('defaults color to #6C63FF when absent', () {
      final json = Map<String, dynamic>.from(baseJson)..remove('color');
      final user = AppUser.fromJson(json);
      expect(user.color, '#6C63FF');
    });

    test('parses email notificationType', () {
      final json = {...baseJson, 'notification_type': 'email'};
      final user = AppUser.fromJson(json);
      expect(user.notificationType, NotificationType.email);
    });
  });

  group('AppUser.toJson', () {
    test('round-trips through fromJson → toJson', () {
      final original = AppUser(
        id: 'u1',
        email: 'bob@example.com',
        name: 'Bob',
        color: '#FF6584',
        emailVerified: true,
        hasGoogleCalendar: false,
        notificationType: NotificationType.push,
      );
      final json = original.toJson();
      final restored = AppUser.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.email, original.email);
      expect(restored.name, original.name);
      expect(restored.color, original.color);
      expect(restored.emailVerified, original.emailVerified);
      expect(restored.hasGoogleCalendar, original.hasGoogleCalendar);
      expect(restored.notificationType, original.notificationType);
    });

    test('serialises notificationType as apiValue string', () {
      final user = AppUser(
        id: 'u1', email: 'a@b.com', name: 'A', color: '#fff',
        notificationType: NotificationType.push,
      );
      expect(user.toJson()['notification_type'], 'push');
    });
  });

  group('AppUser.copyWith', () {
    final base = AppUser(
      id: 'u1',
      email: 'a@b.com',
      name: 'Alice',
      color: '#aaa',
      emailVerified: false,
      hasGoogleCalendar: false,
      notificationType: NotificationType.email,
    );

    test('unchanged fields are preserved', () {
      final copy = base.copyWith(name: 'Bob');
      expect(copy.id, base.id);
      expect(copy.email, base.email);
      expect(copy.color, base.color);
    });

    test('specified field is updated', () {
      final copy = base.copyWith(emailVerified: true);
      expect(copy.emailVerified, isTrue);
    });

    test('hasGoogleCalendar can be toggled', () {
      final copy = base.copyWith(hasGoogleCalendar: true);
      expect(copy.hasGoogleCalendar, isTrue);
      expect(base.hasGoogleCalendar, isFalse); // original unchanged
    });

    test('notificationType can be changed', () {
      final copy = base.copyWith(notificationType: NotificationType.push);
      expect(copy.notificationType, NotificationType.push);
    });
  });
}
