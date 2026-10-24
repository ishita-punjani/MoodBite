import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/features/browse/catalogue_repository.dart';
import 'package:moodbite/features/home/area_picker.dart';
import 'package:moodbite/models/geo_point.dart';
import 'package:moodbite/models/zone.dart';

Zone _zone(String id, String name) => Zone(id: id, name: name, centre: const GeoPoint(19.0, 72.8));

void main() {
  test('sortZonesByName is A to Z, ignores case and does not change the input', () {
    final input = [_zone('1', 'Worli'), _zone('2', 'andheri East'), _zone('3', 'Tardeo'), _zone('4', 'Bandra West')];
    expect(sortZonesByName(input).map((z) => z.name), ['andheri East', 'Bandra West', 'Tardeo', 'Worli']);
    expect(input.first.name, 'Worli');
  });

  testWidgets('the area picker lists areas A to Z even when they arrive in reverse', (tester) async {
    final reversed = [_zone('1', 'Worli'), _zone('2', 'Vile Parle'), _zone('3', 'Tardeo'), _zone('4', 'Colaba')];
    await tester.pumpWidget(ProviderScope(
      overrides: [zonesProvider.overrideWith((ref) async => reversed)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(onPressed: () => showAreaPicker(context), child: const Text('open')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Colaba'), lessThan(top('Tardeo')));
    expect(top('Tardeo'), lessThan(top('Vile Parle')));
    expect(top('Vile Parle'), lessThan(top('Worli')));
  });
}
