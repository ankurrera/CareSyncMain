import 'package:flutter_test/flutter_test.dart';

// Client-side representation of the Appointment FSM
bool isValidAppointmentTransition(String current, String next) {
  if (current == next) return true;
  if (current == 'scheduled') return true; // Legacy fallback allows transitioning to any state

  switch (current) {
    case 'Pending':
      return const ['Confirmed', 'Cancelled', 'Expired'].contains(next);
    case 'Confirmed':
      return const ['Checked In', 'Cancelled', 'No Show'].contains(next);
    case 'Checked In':
      return const ['Consultation Started', 'Cancelled', 'No Show'].contains(next);
    case 'Consultation Started':
      return const ['Consultation Completed'].contains(next);
    case 'Consultation Completed':
      return const ['Prescription Generated', 'Closed'].contains(next);
    case 'Prescription Generated':
      return const ['Closed'].contains(next);
    case 'Closed':
    case 'Cancelled':
    case 'No Show':
    case 'Expired':
      return false; // Terminal states
    default:
      return false;
  }
}

void main() {
  group('Appointment Finite State Machine (FSM) Transition Rules', () {
    test('Allows valid legacy transition from scheduled', () {
      expect(isValidAppointmentTransition('scheduled', 'Pending'), isTrue);
      expect(isValidAppointmentTransition('scheduled', 'Closed'), isTrue);
    });

    test('Allows valid transitions from Pending', () {
      expect(isValidAppointmentTransition('Pending', 'Confirmed'), isTrue);
      expect(isValidAppointmentTransition('Pending', 'Cancelled'), isTrue);
      expect(isValidAppointmentTransition('Pending', 'Expired'), isTrue);
    });

    test('Blocks invalid transitions from Pending', () {
      expect(isValidAppointmentTransition('Pending', 'Checked In'), isFalse);
      expect(isValidAppointmentTransition('Pending', 'Closed'), isFalse);
    });

    test('Allows valid transitions from Confirmed', () {
      expect(isValidAppointmentTransition('Confirmed', 'Checked In'), isTrue);
      expect(isValidAppointmentTransition('Confirmed', 'Cancelled'), isTrue);
      expect(isValidAppointmentTransition('Confirmed', 'No Show'), isTrue);
    });

    test('Blocks invalid transitions from Confirmed', () {
      expect(isValidAppointmentTransition('Confirmed', 'Consultation Started'), isFalse);
    });

    test('Allows valid transitions from Checked In', () {
      expect(isValidAppointmentTransition('Checked In', 'Consultation Started'), isTrue);
      expect(isValidAppointmentTransition('Checked In', 'Cancelled'), isTrue);
    });

    test('Blocks updates on terminal states', () {
      expect(isValidAppointmentTransition('Closed', 'Confirmed'), isFalse);
      expect(isValidAppointmentTransition('Cancelled', 'Pending'), isFalse);
      expect(isValidAppointmentTransition('No Show', 'Confirmed'), isFalse);
      expect(isValidAppointmentTransition('Expired', 'Pending'), isFalse);
    });
  });
}
