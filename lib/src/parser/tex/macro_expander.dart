// katex-sync: src/MacroExpander.ts @ v0.19.1
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

import '../../ast/types.dart';
import 'functions.dart';
import 'lexer.dart';
import 'macros.dart';
import 'namespace.dart';
import 'parse_error.dart';
import 'settings.dart';
import 'source_location.dart';
import 'symbols.dart';
import 'token.dart';

// List of commands that act like macros but aren't defined as a macro,
// function, or symbol.  Used in `isDefined`.
const implicitCommands = {
  '^', // Parser.js
  '_', // Parser.js
  '\\limits', // Parser.js
  '\\nolimits', // Parser.js
};

/// The result of [MacroExpander.consumeArg]. KaTeX: MacroArg.
typedef MacroArg = ({List<Token> tokens, Token start, Token end});

/// The "gullet" where macros are expanded until only non-macro tokens
/// remain.
class MacroExpander implements MacroContext {
  MacroExpander(String input, this.settings, this.mode)
      : macros = Namespace(builtinMacros, settings.macros),
        lexer = Lexer(input, settings);

  TexParserSettings settings;
  @override
  Mode mode;
  int expansionCount = 0;

  /// Tokens in REVERSE order.
  var stack = <Token>[];
  Lexer lexer;
  @override
  Namespace<MacroDefinition> macros;

  String get input => lexer.input;

  /// Feeds a new input string to the same MacroExpander (with the existing
  /// macros).
  void feed(String input) {
    lexer = Lexer(input, settings);
  }

  // switchMode is replaced by the [mode] setter.

  /// Starts a new group nesting within all namespaces.
  void beginGroup() {
    macros.beginGroup();
  }

  /// Ends the current group nesting within all namespaces.
  void endGroup() {
    macros.endGroup();
  }

  /// Ends all nested groups, restoring the values from before the groups.
  /// Useful after an error in the middle of parsing.
  void endGroups() {
    macros.endGroups();
  }

  /// Returns the topmost token on the stack, without expanding it.
  /// Similar in behavior to TeX's `\futurelet`.
  @override
  Token future() {
    if (stack.isEmpty) {
      pushToken(lexer.lex());
    }
    return stack.last;
  }

  /// Removes and returns the next unexpanded token.
  @override
  Token popToken() {
    future(); // ensure non-empty stack
    return stack.removeLast();
  }

  /// Adds a token to the token stack. In particular, this can be used to
  /// put back a token returned from one of the other methods.
  void pushToken(Token token) {
    stack.add(token);
  }

  /// Appends a list of tokens to the token stack.
  void pushTokens(List<Token> tokens) {
    stack.addAll(tokens);
  }

  /// Finds a macro argument without expanding tokens and appends the tokens
  /// to the token stack. Returns a Token that spans the argument, or null
  /// for a missing optional argument.
  @override
  Token? scanArgument({required bool isOptional}) {
    Token start;
    Token end;
    List<Token> tokens;
    if (isOptional) {
      consumeSpaces(); // \@ifnextchar gobbles any space following it
      if (future().text != '[') {
        return null;
      }
      start = popToken(); // don't include [ in tokens
      final arg = consumeArg([']']);
      tokens = arg.tokens;
      end = arg.end;
    } else {
      final arg = consumeArg();
      tokens = arg.tokens;
      start = arg.start;
      end = arg.end;
    }
    // indicate the end of an argument
    pushToken(Token('EOF', end.loc));
    pushTokens(tokens);
    return Token('', SourceLocation.range(start, end));
  }

  /// Consumes all following space tokens, without expansion.
  @override
  void consumeSpaces() {
    while (true) {
      final token = future();
      if (token.text == ' ') {
        stack.removeLast();
      } else {
        break;
      }
    }
  }

  /// Consumes an argument from the token stream. Returns its tokens (in
  /// stack order) and its start and end tokens.
  @override
  MacroArg consumeArg([List<String>? delims]) {
    // The argument for a delimited parameter is the shortest (possibly
    // empty) sequence of tokens with properly nested {...} groups that is
    // followed ... by this particular list of non-parameter tokens.
    // The argument for an undelimited parameter is the next nonblank
    // token, unless that token is ‘{’, when the argument will be the
    // entire {...} group that follows.
    final tokens = <Token>[];
    final isDelimited = delims != null && delims.isNotEmpty;
    if (!isDelimited) {
      // Ignore spaces between arguments. As the TeXbook says:
      // "After you have said ‘\def\row#1#2{...}’, you are allowed to
      //  put spaces between the arguments (e.g., ‘\row x n’), because
      //  TeX doesn’t use single spaces as undelimited arguments."
      consumeSpaces();
    }
    final start = future();
    Token tok;
    var depth = 0;
    var match = 0;
    do {
      tok = popToken();
      tokens.add(tok);
      if (tok.text == '{') {
        ++depth;
      } else if (tok.text == '}') {
        --depth;
        if (depth == -1) {
          throw ParseException('Extra }', tok);
        }
      } else if (tok.text == 'EOF') {
        throw ParseException(
            'Unexpected end of input in a macro argument, expected '
            "'${isDelimited ? delims[match] : '}'}'",
            tok);
      }
      if (isDelimited) {
        if ((depth == 0 || (depth == 1 && delims[match] == '{')) &&
            tok.text == delims[match]) {
          ++match;
          if (match == delims.length) {
            // don't include delims in tokens
            tokens.removeRange(tokens.length - match, tokens.length);
            break;
          }
        } else {
          match = 0;
        }
      }
    } while (depth != 0 || isDelimited);
    // If the argument found ... has the form ‘{<nested tokens>}’,
    // ... the outermost braces enclosing the argument are removed
    if (start.text == '{' && tokens.isNotEmpty && tokens.last.text == '}') {
      tokens
        ..removeLast()
        ..removeAt(0);
    }
    return (tokens: tokens.reversed.toList(), start: start, end: tok);
  }

  /// Consumes [numArgs] (delimited) arguments from the token stream.
  @override
  List<List<Token>> consumeArgs(int numArgs, [List<List<String>>? delimiters]) {
    if (delimiters != null) {
      if (delimiters.length != numArgs + 1) {
        throw ParseException(
            "The length of delimiters doesn't match the number of args!");
      }
      final delims = delimiters[0];
      for (var i = 0; i < delims.length; i++) {
        final tok = popToken();
        if (delims[i] != tok.text) {
          throw ParseException(
              "Use of the macro doesn't match its definition", tok);
        }
      }
    }
    return [
      for (var i = 0; i < numArgs; i++) consumeArg(delimiters?[i + 1]).tokens,
    ];
  }

  /// Increments [expansionCount] by [amount]. Throws if it exceeds
  /// maxExpand.
  void countExpansion(int amount) {
    expansionCount += amount;
    if (expansionCount > settings.maxExpand) {
      throw ParseException('Too many expansions: infinite loop or '
          'need to increase maxExpand setting');
    }
  }

  /// Expands the next token only once if possible.
  ///
  /// If the token is expanded, the resulting tokens are pushed onto the
  /// stack in reverse order, and the number of such tokens is returned.
  /// This number might be zero or positive.
  ///
  /// If not, the return value is null (KaTeX: false), and the next token
  /// remains at the top of the stack.
  ///
  /// If [expandableOnly], only expandable tokens are expanded and an
  /// undefined control sequence results in an error.
  @override
  int? expandOnce([bool expandableOnly = false]) {
    final topToken = popToken();
    final name = topToken.text;
    final expansion = !topToken.noexpand ? _getExpansion(name) : null;
    if (expansion == null || (expandableOnly && expansion.unexpandable)) {
      if (expandableOnly &&
          expansion == null &&
          name.startsWith('\\') &&
          !isDefined(name)) {
        throw ParseException('Undefined control sequence: $name');
      }
      pushToken(topToken);
      return null;
    }
    countExpansion(1);
    var tokens = expansion.tokens;
    final args = consumeArgs(expansion.numArgs, expansion.delimiters);
    if (expansion.numArgs != 0) {
      // paste arguments in place of the placeholders
      tokens = tokens.toList(); // make a shallow copy
      for (var i = tokens.length - 1; i >= 0; --i) {
        var tok = tokens[i];
        if (tok.text == '#') {
          if (i == 0) {
            throw ParseException(
                'Incomplete placeholder at end of macro body', tok);
          }
          tok = tokens[--i]; // next token on stack
          if (tok.text == '#') {
            // ## → #
            tokens.removeAt(i + 1); // drop first #
          } else if (_argNumber.hasMatch(tok.text)) {
            // replace the placeholder with the indicated argument
            tokens.replaceRange(i, i + 2, args[int.parse(tok.text) - 1]);
          } else {
            throw ParseException('Not a valid argument number', tok);
          }
        }
      }
    }
    // Concatenate expansion onto top of stack.
    pushTokens(tokens);
    return tokens.length;
  }

  static final _argNumber = RegExp(r'^[1-9]$');

  /// Expands the next token only once (if possible), and returns the
  /// resulting top token on the stack (without removing anything from the
  /// stack). Similar in behavior to TeX's `\expandafter\futurelet`.
  @override
  Token expandAfterFuture() {
    expandOnce();
    return future();
  }

  /// Recursively expands the first token, then returns the first
  /// non-expandable token.
  @override
  Token expandNextToken() {
    while (true) {
      if (expandOnce() == null) {
        // fully expanded
        final token = stack.removeLast();
        // the token after \noexpand is interpreted as if its meaning were
        // ‘\relax’
        if (token.treatAsRelax) {
          token.text = '\\relax';
        }
        return token;
      }
    }
  }

  /// Fully expands the macro [name] and returns the resulting tokens, or
  /// null if no such macro is defined.
  List<Token>? expandMacro(String name) =>
      macros.has(name) ? expandTokens([Token(name)]) : null;

  /// Fully expands [tokens] and returns the resulting tokens. The input
  /// tokens are in reverse order; the output tokens are in forward order.
  @override
  List<Token> expandTokens(List<Token> tokens) {
    final output = <Token>[];
    final oldStackLength = stack.length;
    pushTokens(tokens);
    while (stack.length > oldStackLength) {
      // Expand only expandable tokens
      if (expandOnce(true) == null) {
        // fully expanded
        final token = stack.removeLast();
        if (token.treatAsRelax) {
          // the expansion of \noexpand is the token itself
          token
            ..noexpand = false
            ..treatAsRelax = false;
        }
        output.add(token);
      }
    }
    // Count all of these tokens as additional expansions, to prevent
    // exponential blowup from linearly many \edef's.
    countExpansion(output.length);
    return output;
  }

  /// Fully expands the macro [name] and returns the result as a string, or
  /// null if no such macro is defined.
  String? expandMacroAsText(String name) =>
      expandMacro(name)?.map((token) => token.text).join();

  MacroExpansion? _getExpansion(String name) {
    final definition = macros.get(name);
    if (definition == null) {
      return null;
    }
    // If a single character has an associated catcode other than 13
    // (active character), then don't expand it.
    if (name.length == 1) {
      final catcode = lexer.catCodes[name];
      if (catcode != null && catcode != 13) {
        return null;
      }
    }
    return definition.expand(this);
  }

  /// Whether a command is "defined" (has some functionality): a macro (in
  /// the current group), a function, a symbol, or one of the
  /// [implicitCommands].
  @override
  bool isDefined(String name) =>
      macros.has(name) ||
      texSymbolCommandConfigs[Mode.math]!.containsKey(name) ||
      texSymbolCommandConfigs[Mode.text]!.containsKey(name) ||
      functions.containsKey(name) ||
      implicitCommands.contains(name);

  /// Whether a command is expandable.
  @override
  bool isExpandable(String name) {
    final macro = macros.get(name);
    if (macro != null) return macro.expandable;
    final function = functions[name];
    return function != null && !function.primitive;
  }

  @override
  Lexer getNewLexer(String input) => Lexer(input, settings);
}

/// KaTeX: MacroContextInterface (src/defineMacro.ts).
abstract class MacroContext {
  Mode get mode;
  Namespace<MacroDefinition> get macros;
  Token future();
  Token popToken();
  void consumeSpaces();
  // ignore: avoid_positional_boolean_parameters
  int? expandOnce([bool expandableOnly]);
  Token expandAfterFuture();
  Token expandNextToken();
  List<Token> expandTokens(List<Token> tokens);
  MacroArg consumeArg([List<String>? delims]);
  List<List<Token>> consumeArgs(int numArgs, [List<List<String>>? delimiters]);
  Token? scanArgument({required bool isOptional});
  bool isDefined(String name);
  bool isExpandable(String name);

  Lexer getNewLexer(String input);
}
