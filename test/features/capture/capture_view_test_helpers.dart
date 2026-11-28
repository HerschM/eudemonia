import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A little longer than the panel's slide (220 ms). Not pumpAndSettle: the ink ripples of the taps
// take about 600 ms each to fade, which would let the unread-dwell timers (3 s) run out.
const _panelSlide = Duration(milliseconds: 250);

/// Opens the Capture view panel from the bar, picks a Show and/or a Status row (the enum names
/// of `CaptureTriageFilter` / `CaptureStatusFilter`, such as `unread` or `failed`) and closes the
/// panel again with the bar button, as a user does. Replaces the two dropdowns the screen had
/// before the user's decision of 2026-11-28 ("the capture screen should also have a similar view
/// instead of two dropdowns").
/// One frame to start the change, then long enough for the panel to finish sliding.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_panelSlide);
}

Future<void> pickCaptureView(WidgetTester tester, {String? show, String? status}) async {
  await tester.tap(find.byKey(const Key('capture_view_button')));
  await _settle(tester);
  if (show != null) {
    await tester.tap(find.byKey(Key('capture_view_show_$show')));
    await _settle(tester);
  }
  if (status != null) {
    await tester.tap(find.byKey(Key('capture_view_status_$status')));
    await _settle(tester);
  }
  await tester.tap(find.byKey(const Key('capture_view_button')));
  await _settle(tester);
}
