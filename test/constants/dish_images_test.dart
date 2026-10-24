import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/constants/dish_images.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/widgets/dish_image.dart';

DishImageResolver everyPhoto() => DishImageResolver({
      for (final type in DishImageTypes.all) DishImageResolver.assetPath(type.slug),
    });

DishImageResolver categoryPhotosOnly() => DishImageResolver({
      for (final slug in DishImageTypes.categoryFallback.values) DishImageResolver.assetPath(slug),
    });

List<Map<String, String>> readDishes() {
  final lines = const LineSplitter().convert(File('data/dishes.csv').readAsStringSync());
  // Minimal CSV reader: quoted fields may contain commas.
  List<String> split(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (c == ',' && !quoted) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    return fields..add(buffer.toString());
  }

  final header = split(lines.first);
  return [
    for (final line in lines.skip(1).where((l) => l.trim().isNotEmpty)) Map.fromIterables(header, split(line)),
  ];
}

void main() {
  group('DishImageResolver', () {
    test('keyword match on the dish name picks the matching type', () {
      final resolver = everyPhoto();
      expect(resolver.assetFor('Chicken Dum Biryani', 'rice'), 'assets/dishes/biryani.jpg');
      expect(resolver.assetFor('Samosa Chaat', 'street_food'), 'assets/dishes/chaat.jpg');
      expect(resolver.assetFor('Cold Coffee with Ice Cream', 'beverage'), 'assets/dishes/coffee.jpg');
      expect(resolver.assetFor('Paneer Tikka', 'starter'), 'assets/dishes/paneer-tikka.jpg');
    });

    test('an unknown dish falls back to its category photo', () {
      expect(everyPhoto().assetFor('Mystery Special', 'dessert'), 'assets/dishes/indian-sweet.jpg');
      expect(everyPhoto().assetFor('Mystery Special', 'main'), 'assets/dishes/paneer-curry.jpg');
    });

    test('an unknown dish in an unknown category has no photo (emoji placeholder)', () {
      expect(everyPhoto().assetFor('Mystery Special', 'weird'), isNull);
    });

    test('with zero images every dish resolves to null so the app shows emoji', () {
      for (final dish in readDishes()) {
        expect(DishImageResolver.none.assetFor(dish['name']!, dish['category']!), isNull);
      }
    });

    test('a type whose photo is missing falls through to the category photo', () {
      final resolver = categoryPhotosOnly();
      expect(resolver.assetFor('Chicken Dum Biryani', 'rice'), 'assets/dishes/comfort-rice.jpg');
    });

    test('every dish in data/dishes.csv is matched by a keyword (none needs the fallback)', () {
      final resolver = everyPhoto();
      final slugsByName = {for (final t in DishImageTypes.all) t.slug};
      for (final dish in readDishes()) {
        final lower = dish['name']!.toLowerCase();
        final matched = DishImageTypes.all.where((t) => t.keywords.any(lower.contains));
        expect(matched, isNotEmpty, reason: 'no photo type for "${dish['name']}"');
        expect(slugsByName, contains(matched.first.slug));
        expect(resolver.assetFor(dish['name']!, dish['category']!), isNotNull);
      }
    });

    test('vegetarian dishes never get a meat or fish photo', () {
      const meat = {'chicken-curry', 'mutton-curry', 'prawns', 'fish-fry', 'fish-curry'};
      for (final dish in readDishes().where((d) => d['is_veg'] == 'true')) {
        final lower = dish['name']!.toLowerCase();
        final type = DishImageTypes.all.firstWhere((t) => t.keywords.any(lower.contains));
        expect(meat, isNot(contains(type.slug)), reason: '${dish['name']} is veg but maps to ${type.slug}');
      }
    });

    test('category fallbacks only use real photo types and cover every dish category', () {
      final slugs = {for (final t in DishImageTypes.all) t.slug};
      expect(slugs, containsAll(DishImageTypes.categoryFallback.values));
      expect(DishImageTypes.categoryFallback.keys, containsAll(readDishes().map((d) => d['category']).toSet()));
    });
  });

  test('the Dart type table is identical to the one in scripts/fetch_images.py', () {
    final script = File('scripts/fetch_images.py').readAsStringSync();
    final entry = RegExp(r'^\s*\("([a-z-]+)", "[^"]*", \[([^\]]*)\]\),$', multiLine: true);
    final fromScript = [
      for (final m in entry.allMatches(script))
        '${m.group(1)}: ${[for (final k in RegExp(r'"([^"]*)"').allMatches(m.group(2)!)) k.group(1)!].join('|')}',
    ];
    final fromDart = [for (final t in DishImageTypes.all) '${t.slug}: ${t.keywords.join('|')}'];
    expect(fromScript, fromDart);
  });

  group('DishImage widget', () {
    Widget host(Widget child, DishImageResolver resolver) => ProviderScope(
          overrides: [dishImageResolverProvider.overrideWith((ref) async => resolver)],
          child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
        );

    testWidgets('shows the labelled emoji placeholder when no photo exists', (tester) async {
      final semantics = tester.ensureSemantics();
        await tester.pumpWidget(host(
        const DishImage(name: 'Masala Dosa', category: 'south_indian', width: 72, height: 72),
        DishImageResolver.none,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('🥞'), findsOneWidget);
      expect(find.bySemanticsLabel('South indian dish'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the placeholder is a rounded tile with a category-tinted gradient in the photo slot', (tester) async {
      await tester.pumpWidget(host(
        const DishImage(name: 'Gulab Jamun', category: 'dessert', width: 72, height: 72),
        DishImageResolver.none,
      ));
      await tester.pumpAndSettle();
      final tile = tester.widget<Container>(find.byType(Container).first);
      final decoration = tile.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      expect((decoration.gradient! as LinearGradient).colors.last, AppColors.categoryTint('dessert'));
      expect(decoration.borderRadius, isNotNull);
      expect(tester.getSize(find.byType(Container).first), const Size(72, 72));
      expect(AppColors.categoryTint('dessert'), isNot(AppColors.categoryTint('beverage')));
    });

    testWidgets('shows the photo when one is bundled', (tester) async {
      await tester.pumpWidget(host(
        const DishImage(name: 'Masala Dosa', category: 'south_indian', width: 72, height: 72),
        everyPhoto(),
      ));
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, 'Masala Dosa');
    });
  });
}
