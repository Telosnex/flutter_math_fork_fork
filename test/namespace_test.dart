// Namespace behavior from KaTeX v0.19.1 src/Namespace.ts.
import 'package:flutter_math_fork_fork/src/parser/tex/namespace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two local sets in one group restore the value from before', () {
    final ns = Namespace<String>({}, {'x': 'outer'});
    ns.beginGroup();
    ns.set('x', 'one');
    ns.set('x', 'two');
    ns.endGroup();
    expect(ns.get('x'), 'outer');
  });

  test('a local definition of a new name is removed at group end', () {
    final ns = Namespace<String>({}, {});
    ns.beginGroup();
    ns.set('y', 'local');
    ns.endGroup();
    expect(ns.has('y'), isFalse);
  });

  test('global set survives the group', () {
    final ns = Namespace<String>({}, {'x': 'outer'});
    ns.beginGroup();
    ns.set('x', 'local');
    ns.set('x', 'global', global: true);
    ns.endGroup();
    expect(ns.get('x'), 'global');
  });

  test('set to null removes the local definition', () {
    final ns = Namespace<String>({'x': 'builtin'}, {'x': 'current'});
    ns.set('x', null);
    expect(ns.get('x'), 'builtin');
  });

  test('endGroups closes all groups', () {
    final ns = Namespace<String>({}, {'x': 'outer'});
    ns
      ..beginGroup()
      ..set('x', 'a')
      ..beginGroup()
      ..set('x', 'b')
      ..endGroups();
    expect(ns.get('x'), 'outer');
    expect(ns.undefStack, isEmpty);
  });
}
