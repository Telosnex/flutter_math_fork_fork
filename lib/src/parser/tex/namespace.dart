// katex-sync: src/Namespace.ts @ v0.19.1
// The MIT License (MIT)
//
// Copyright (c) 2013-2019 Khan Academy and other contributors
// Copyright (c) 2020 znjameswu <znjameswu@gmail.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'parse_error.dart';

class Namespace<T extends Object> {
  Namespace(this.builtins, Map<String, T> current)
      : current = Map.from(current);
  final Map<String, T> current;
  final Map<String, T> builtins;

  /// For each open group, the values to restore at its end. A null value
  /// means "not defined before the group".
  final undefStack = <Map<String, T?>>[];

  T? get(String name) => current[name] ?? builtins[name];

  /// Sets [name] to [value]. A null [value] removes the local definition.
  /// [global] sets the value in all groups.
  void set(String name, T? value, {bool global = false}) {
    if (global) {
      // Global set is equivalent to setting in all groups. Simulate this by
      // destroying any undos currently scheduled for this name, and adding
      // an undo with the *new* value (in case it later gets locally reset
      // within this environment).
      for (final undef in undefStack) {
        undef.remove(name);
      }
      if (undefStack.isNotEmpty) {
        undefStack.last[name] = value;
      }
    } else {
      // Undo this set at the end of this group, unless an undo is already
      // in place, in which case that older value is the correct one.
      final top = undefStack.isEmpty ? null : undefStack.last;
      if (top != null && !top.containsKey(name)) {
        top[name] = current[name];
      }
    }
    if (value == null) {
      current.remove(name);
    } else {
      current[name] = value;
    }
  }

  bool has(String name) =>
      current.containsKey(name) || builtins.containsKey(name);

  void beginGroup() {
    undefStack.add({});
  }

  void endGroup() {
    if (undefStack.isEmpty) {
      throw ParseException('Unbalanced namespace destruction: attempt '
          'to pop global namespace; please report this as a bug');
    }
    final undefs = undefStack.removeLast();
    undefs.forEach((key, value) {
      if (value == null) {
        current.remove(key);
      } else {
        current[key] = value;
      }
    });
  }

  /// Ends all open groups, restoring the global namespace.
  void endGroups() {
    while (undefStack.isNotEmpty) {
      endGroup();
    }
  }
}
