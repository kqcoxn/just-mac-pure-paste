#!/usr/bin/env python3
"""Expand one environment macro and omit design-time previews in the locked dependency.
Only touches the disposable .build checkout; never changes its version or hotkey code.
Also adds app-bundle resource discovery required by signed macOS bundles.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
source = root / '.build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts'
path = source / 'Utilities.swift'
text = path.read_text()
old_resource = 'NSLocalizedString(self, bundle: .module, comment: self)'
new_resource = 'let packagedBundle = Bundle.main.url(forResource: "KeyboardShortcuts_KeyboardShortcuts", withExtension: "bundle").flatMap { Bundle(url: $0) }\n        return NSLocalizedString(self, bundle: packagedBundle ?? .module, comment: self)'
if old_resource in text:
    path.chmod(path.stat().st_mode | 0o200)
    path.write_text(text.replace(old_resource, new_resource))
elif new_resource not in text:
    raise SystemExit('Unexpected localization source; refusing compatibility edit')
if '--clt' not in sys.argv:
    raise SystemExit(0)
path = source / 'ConflictPolicy.swift'
old = '''extension EnvironmentValues {
\t@Entry
\tvar keyboardShortcutsConflictPolicy = KeyboardShortcuts.ConflictPolicy.default
}'''
new = '''private struct KeyboardShortcutsConflictPolicyKey: EnvironmentKey {
    static let defaultValue = KeyboardShortcuts.ConflictPolicy.default
}

extension EnvironmentValues {
    var keyboardShortcutsConflictPolicy: KeyboardShortcuts.ConflictPolicy {
        get { self[KeyboardShortcutsConflictPolicyKey.self] }
        set { self[KeyboardShortcutsConflictPolicyKey.self] = newValue }
    }
}'''
text = path.read_text()
if old in text:
    path.chmod(path.stat().st_mode | 0o200)
    path.write_text(text.replace(old, new))
elif new not in text:
    raise SystemExit('Unexpected KeyboardShortcuts source; refusing compatibility edit')
path = source / 'Recorder.swift'
text = path.read_text()
patched, count = re.subn(r'\n#Preview \{\n.*?\n\}\n', '\n', text, flags=re.S)
if count not in (0, 3):
    raise SystemExit('Unexpected preview count; refusing compatibility edit')
if count:
    path.chmod(path.stat().st_mode | 0o200)
    path.write_text(patched)
print('Command Line Tools compatibility applied to KeyboardShortcuts 3.1.0 cache.')
