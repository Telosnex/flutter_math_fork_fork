// Jest setup file for the KaTeX test suite. ADR 001, D2 and D3.
//
// It wraps KaTeX src/parseTree so that each call records the input, the
// settings that affect parsing, and the result. katex_sync.dart runs jest
// with this file and reads the records. Run it only through that tool.
//
// Output: one JSON Lines file for each KaTeX test file, in the directory
// that the environment variable KATEX_RECORD_DIR names.
//
// This is the only JavaScript file in this repository. It is CommonJS so
// that jest loads it without a transform.

'use strict';

const fs = require('fs');
const path = require('path');

const recordDir = process.env.KATEX_RECORD_DIR;
if (!recordDir) {
  throw new Error('record_parse_calls.js: set KATEX_RECORD_DIR');
}

// The KaTeX checkout is the jest root directory.
const parseTreeModule = require(path.join(process.cwd(), 'src', 'parseTree'));
const ParseError = require(path.join(process.cwd(), 'src', 'ParseError'))
  .default;
const Settings = require(path.join(process.cwd(), 'src', 'Settings')).default;

const original = parseTreeModule.default;
if (typeof original !== 'function') {
  throw new Error('record_parse_calls.js: src/parseTree has no default ' +
    'export. KaTeX changed; update this hook (ADR 001 risk 5).');
}

const records = [];

function settingValue(value) {
  if (typeof value === 'function') return '<function>';
  return value;
}

function macrosValue(macros) {
  const out = {};
  let portable = true;
  for (const key of Object.keys(macros || {}).sort()) {
    const value = macros[key];
    if (typeof value === 'string') {
      out[key] = value;
    } else {
      out[key] = typeof value === 'function' ? '<function>' : '<object>';
      portable = false;
    }
  }
  return {out, portable};
}

function snapshotSettings(given) {
  // Some tests give a plain object. Settings fills in the defaults.
  const settings = given instanceof Settings ? given : new Settings(given);
  const macros = macrosValue(settings.macros);
  return {
    // Some tests give truthy numbers (display: 1 in ss_data.yaml). KaTeX
    // tests the truth value, so record a boolean.
    settings: {
      colorIsTextColor: Boolean(settings.colorIsTextColor),
      displayMode: Boolean(settings.displayMode),
      globalGroup: Boolean(settings.globalGroup),
      macros: macros.out,
      maxExpand: settings.maxExpand,
      strict: settingValue(settings.strict),
      trust: settingValue(settings.trust),
    },
    portable: macros.portable &&
      typeof settings.strict !== 'function' &&
      typeof settings.trust !== 'function',
  };
}

function currentTestName() {
  try {
    return expect.getState().currentTestName || '';
  } catch (e) {
    return '';
  }
}

function wrapped(toParse, settings) {
  // Dart input is always a String. Skip the TypeError tests.
  if (!(typeof toParse === 'string' || toParse instanceof String)) {
    return original.apply(this, arguments);
  }
  // Copy the settings first. A parse can add macros to settings.macros.
  const snap = snapshotSettings(settings);
  const tex = String(toParse);
  const record = {
    tex,
    settings: snap.settings,
    portable: snap.portable,
    source: currentTestName(),
  };
  try {
    const result = original.apply(this, arguments);
    record.katex = {ok: true};
    records.push(record);
    return result;
  } catch (error) {
    if (error instanceof ParseError) {
      record.katex = {
        ok: false,
        kind: 'ParseError',
        message: error.rawMessage,
        position: error.position === undefined ? null : error.position,
      };
    } else {
      record.katex = {
        ok: false,
        kind: (error && error.constructor && error.constructor.name) ||
          'Error',
        message: String(error && error.message),
        position: null,
      };
    }
    records.push(record);
    throw error;
  }
}

parseTreeModule.default = wrapped;

afterAll(() => {
  const testPath = expect.getState().testPath || 'unknown';
  const name = path.basename(testPath).replace(/\.[jt]s$/, '');
  fs.mkdirSync(recordDir, {recursive: true});
  const lines = records.map((r) => JSON.stringify({file: name, ...r}));
  fs.writeFileSync(
    path.join(recordDir, name + '.jsonl'),
    lines.length ? lines.join('\n') + '\n' : '');
});
