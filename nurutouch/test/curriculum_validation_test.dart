import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Curriculum Validation Tests', () {
    late Map<String, dynamic> curriculumData;

    setUpAll(() {
      final file = File('assets/curriculum/lessons.json');
      if (!file.existsSync()) {
        fail('lessons.json not found at ${file.path}');
      }
      final jsonStr = file.readAsStringSync();
      curriculumData = json.decode(jsonStr);
    });

    test('Validates English Curriculum', () {
      _validateLanguage(curriculumData['english'], 'English');
    });

    test('Validates Swahili Curriculum', () {
      _validateLanguage(curriculumData['swahili'], 'Swahili');
    });

    test('Ensures English and Swahili have structural parity', () {
      final en = curriculumData['english'] as List;
      final sw = curriculumData['swahili'] as List;

      // Ensure both have identical schema structure per lesson type
      final enSchemas = _getSchemaMap(en);
      final swSchemas = _getSchemaMap(sw);

      for (final type in enSchemas.keys) {
        expect(swSchemas.containsKey(type), true, reason: 'Swahili is missing lesson type $type');
        final enFields = enSchemas[type]!;
        final swFields = swSchemas[type]!;
        expect(enFields.difference(swFields).isEmpty, true, reason: 'English $type has fields not in Swahili');
        expect(swFields.difference(enFields).isEmpty, true, reason: 'Swahili $type has fields not in English');
      }
    });
  });
}

Map<String, Set<String>> _getSchemaMap(List lessons) {
  final map = <String, Set<String>>{};
  for (final l in lessons) {
    final type = l['type'] ?? 'unknown';
    map.putIfAbsent(type, () => <String>{});
    map[type]!.addAll((l as Map<String, dynamic>).keys);
  }
  return map;
}

void _validateLanguage(List? lessons, String languageName) {
  expect(lessons, isNotNull, reason: '$languageName curriculum is null');
  final nodes = <String, Map<String, dynamic>>{};
  
  for (final l in lessons!) {
    final id = l['id'];
    expect(id, isNotNull, reason: 'Lesson missing ID');
    nodes[id] = l;

    // Validate canonical schema: no target_dots or letters at root level
    expect(l.containsKey('target_dots'), isFalse, reason: '$id uses deprecated target_dots at root level');
    expect(l.containsKey('letters'), isFalse, reason: '$id uses deprecated letters at root level');
    expect(l.containsKey('dots'), isFalse, reason: '$id uses deprecated dots at root level');
    expect(l.containsKey('sequence'), isTrue, reason: '$id is missing the canonical sequence field');
    
    // Ensure difficulty is computed and exists
    expect(l.containsKey('difficulty'), isTrue, reason: '$id is missing difficulty');
  }

  // Check graph properties
  final graph = <String, List<String>>{};
  final reverseGraph = <String, List<String>>{};
  for (final id in nodes.keys) {
    graph[id] = [];
    reverseGraph[id] = [];
  }

  for (final l in lessons) {
    final id = l['id'];
    final prereqs = List<String>.from(l['prerequisites'] ?? []);
    for (final p in prereqs) {
      expect(nodes.containsKey(p), isTrue, reason: 'Dangling prerequisite: $id requires missing $p');
      graph[p]!.add(id);
      reverseGraph[id]!.add(p);
    }
  }

  // Unreachable check
  final entryPoints = nodes.keys.where((id) => reverseGraph[id]!.isEmpty).toList();
  expect(entryPoints.isNotEmpty, isTrue, reason: 'No entry points found (possible total cycle)');

  final reachable = <String>{};
  final queue = List<String>.from(entryPoints);
  while (queue.isNotEmpty) {
    final curr = queue.removeAt(0);
    if (!reachable.contains(curr)) {
      reachable.add(curr);
      queue.addAll(graph[curr]!);
    }
  }

  for (final id in nodes.keys) {
    expect(reachable.contains(id), isTrue, reason: 'Unreachable node: $id');
  }

  // Cycle check (Kahn's)
  final inDegree = <String, int>{};
  for (final id in nodes.keys) {
    inDegree[id] = reverseGraph[id]!.length;
  }

  final zeroIn = inDegree.keys.where((k) => inDegree[k] == 0).toList();
  int visited = 0;
  while (zeroIn.isNotEmpty) {
    final u = zeroIn.removeAt(0);
    visited++;
    for (final v in graph[u]!) {
      inDegree[v] = inDegree[v]! - 1;
      if (inDegree[v] == 0) {
        zeroIn.add(v);
      }
    }
  }

  expect(visited, equals(nodes.length), reason: 'Cycle detected in curriculum graph');
}
