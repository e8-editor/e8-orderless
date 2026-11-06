# e8-orderless

A completion style for [E8](https://github.com/e8-editor/e8) that splits what you type at spaces and matches the candidates that match every word, in any order: `fil ot` finds `find-file-other-window`. A port of [orderless](https://github.com/oantolin/orderless) 1.5.

## Installing

In `~/.config/e8/init.ts`:

```ts
e8.usePackage("e8-editor/e8-orderless");
e8.setVariable("completion-styles", ["orderless", "basic"]);
```

E8 installs it at its newest version tag into `repos/` beside `init.ts`, records the commit in `e8-lock.json`, and requires it. `M-x package-vc-upgrade` brings it up to date. Pin a version with `{ rev: "v0.1.0" }`. It needs E8 0.3.1 or newer.

`basic` after `orderless` keeps the usual prefix completion for what orderless cannot do. File names usually complete better by parts, `/u/s/l` for `/usr/share/local`:

```ts
e8.setVariable("completion-category-overrides", [["file", ["styles", "partial-completion"]]]);
```

orderless is a style, not a way of showing candidates: it is meant for a list that shows what it matches as you type, such as [e8-vertico](https://github.com/e8-editor/e8-vertico)'s.

## Using it

Each word of the input, a component, matches as a literal string or as an Emacs regexp (`^al`, `bet$`). A character at the start or end of a component, from `orderless-affix-dispatch-alist`, matches it another way:

| Character | The rest of the component matches |
| --- | --- |
| `!` | candidates that do not match it |
| `,` | as an initialism: `,ffow` for `find-file-other-window` |
| `=` | literally |
| `^` | as a literal prefix |
| `~` | flex: its characters in order, with anything between |
| `&` | against the candidate's annotation rather than its text |
| `%` | literally (see below) |

Input in lower case ignores case; input with an upper case letter matches case. A backslash before a space makes it part of a component.

Variables:

- `orderless-matching-styles`: how a component matches, `["orderless-literal", "orderless-regexp"]`; also `orderless-literal-prefix`, `orderless-flex`, `orderless-initialism`, `orderless-prefixes` and `orderless-without-literal`.
- `orderless-affix-dispatch-alist`, `orderless-style-dispatchers`: the characters above, and the functions that choose a component's styles.
- `orderless-component-separator`: what splits the input, a regexp or a function.
- `orderless-smart-case`: whether upper case in the input matches case.
- `orderless-match-faces`: the faces of each component's matches, `orderless-match-face-0` to `-3` in turn.

Other packages can import `orderlessFilter`, `orderlessCompile`, `orderlessHighlightMatches` and the matching styles from `"orderless"`.

## Differences from orderless.el

- E8 has no character folding yet, so `%` matches literally.
- The style only lists completions: it has no try-completion, so `orderless-expand-substring` is not there, and `TAB` and `M-x` without a list such as vertico's go on to the next of `completion-styles`.
- `orderless-define-completion-style`, the Ivy functions and `orderless-kwd.el` are not ported.

## Credit

This is a port to E8 of [orderless](https://github.com/oantolin/orderless) 1.5, by Omar Antolín Camarena, maintained with Daniel Mendler, copyright the Free Software Foundation, and distributed in GNU ELPA, under the GNU General Public License version 3 or later. It is not the upstream authors' work as published, and they do not endorse it: report problems with the port here, not upstream.

## Developing

With an E8 on your PATH (a [release](https://github.com/e8-editor/e8/releases), or built from source) and TypeScript 5.8 or newer:

```bash
make test
make types
```

The tests need [e8-vertico](https://github.com/e8-editor/e8-vertico), which `make` clones into `.e8/deps`. The tests in `test/orderless-tests.ts` type the keys of each case in `test/cases.json` at a vertico prompt, some at file name prompts in a directory made for them, and check, after each key, the input, the count and the candidates, and the answer, against what orderless.el 1.5 and vertico.el 2.5 showed in Emacs 30 for the same keys, recorded in `test/golden.json`. `test/record.el` records them again, in an Emacs on a terminal:

```bash
script -q /dev/null emacs -Q -nw -l test/record.el
```

It loads vertico and orderless from `~/.emacs.d/elpaca/repos`, or from the directory `E8_ELPA` names.

## Licence

GPL-3.0-or-later: see `LICENSE`.
