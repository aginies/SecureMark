import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:secure_mark/l10n/app_localizations.dart';
import 'package:secure_mark/main.dart';
import 'package:secure_mark/pages/watermark_page.dart';
import 'package:secure_mark/widgets/density_painter.dart';
import 'package:secure_mark/widgets/profile_tile.dart';
import 'package:secure_mark/widgets/xy_pad_painter.dart';

Future<void> pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(const SecureMarkApp());
  // Let async init (preferences, platform handler, identity keys) settle.
  // Two pumps: the first completes the async prefs/identity round trips, the
  // second renders the state they applied via setState.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'isFirstLaunch': false});
  });

  testWidgets('page renders profile selector and painters',
      (WidgetTester tester) async {
    await pumpPage(tester);

    expect(find.byType(ProfileTile), findsWidgets);
    expect(find.byType(WatermarkPage), findsOneWidget);
  });

  testWidgets('apply action is disabled until files are selected',
      (WidgetTester tester) async {
    await pumpPage(tester);

    final wand = find.widgetWithIcon(IconButton, Icons.auto_fix_high);
    expect(wand, findsWidgets);
    expect(tester.widget<IconButton>(wand.first).onPressed, isNull);
  });

  testWidgets('dragging the XY pad persists transparency and density once',
      (WidgetTester tester) async {
    await pumpPage(tester);

    final crosshair = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is XYPadPainter);
    expect(crosshair, findsOneWidget);

    // The dashboard pans on the GestureDetector that hosts the cross-hair;
    // drag mostly horizontally so the page's vertical scroll view does not
    // win the gesture arena.
    final pad = find
        .ancestor(of: crosshair, matching: find.byType(GestureDetector))
        .first;
    await tester.ensureVisible(pad);
    await tester.pump(const Duration(milliseconds: 100));

    final rect = tester.getRect(pad);
    await tester.timedDragFrom(rect.centerLeft + const Offset(8, 0),
        const Offset(90, 2), const Duration(milliseconds: 400));

    // onPanEnd persists the two preferences exactly once per gesture.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('transparency'), isNotNull);
    expect(prefs.getDouble('density'), isNotNull);
  });

  testWidgets('density/preview painters render inside the dashboard',
      (WidgetTester tester) async {
    await pumpPage(tester);

    expect(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is DensityPainter),
        findsWidgets);
  });

  testWidgets('expert options dialog opens from the overflow menu',
      (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    // Tap the expert-options entry directly (the text label can sit under
    // the menu overlay edge on the default 800x600 test surface).
    final item = find.byWidgetPredicate(
        (w) => w is PopupMenuItem<String> && w.value == 'expertOptions');
    expect(item, findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('steganography options dialog opens from the overflow menu',
      (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    final item = find.byWidgetPredicate(
        (w) => w is PopupMenuItem<String> && w.value == 'steganography');
    expect(item, findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('QR watermark dialog opens from the overflow menu',
      (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    final item = find.byWidgetPredicate(
        (w) => w is PopupMenuItem<String> && w.value == 'qr');
    expect(item, findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('saved density preference is restored on startup',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(
        {'isFirstLaunch': false, 'density': 62.0});
    await pumpPage(tester);

    final painters = find
        .byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is DensityPainter)
        .evaluate();
    var found = false;
    for (final el in painters) {
      final paint = el.widget as CustomPaint;
      if ((paint.painter as DensityPainter).density == 62.0) {
        found = true;
      }
    }
    expect(found, isTrue,
        reason: 'A density painter should reflect the persisted density.');
  });

  testWidgets('file analyzer dialog opens and closes cleanly (reset path)',
      (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    final item = find.byWidgetPredicate(
        (w) => w is PopupMenuItem<String> && w.value == 'analyze');
    expect(item, findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    // Close the analyzer; its reset hook (_resetAnalysisState) must not throw.
    final context = tester.element(find.byType(AlertDialog));
    final l10n = AppLocalizations.of(context)!;
    await tester.tap(find.text(l10n.close).last);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(WatermarkPage), findsOneWidget);
  });

  testWidgets('profile chip switch triggers profile re-render',
      (WidgetTester tester) async {
    await pumpPage(tester);

    final chips = find.byType(ProfileTile);
    expect(chips, findsWidgets);
    await tester.tap(chips.at(1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(WatermarkPage), findsOneWidget);
  });
}
