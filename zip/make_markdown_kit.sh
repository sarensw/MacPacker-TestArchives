#!/bin/bash
#
# Rebuilds `markdown-kit.zip` — a small but *real* JavaScript repository: it
# installs, builds and tests. Everything sits at the archive root, so a viewer
# opening it lands straight on `README.md` next to `package.json` and `src/`.
#
# Two fixtures in one:
#
#   1. The screenshot frame. MacPacker's plan opens it and selects `README.md`
#      to show the preview feature (see MacPacker's `sandboxpilot.json`), which
#      wants an archive that reads as a source checkout at a glance.
#   2. Groundwork for archiving a checkout while honoring its `.gitignore`. That
#      needs a folder whose ignored entries actually exist, so a test can extract
#      this, run `npm install` and `npm run build` to produce `node_modules/` and
#      `dist/`, re-archive the folder, and assert both are absent.
#
# Point 2 is why `package.json` carries a real devDependency and a build script
# rather than being a plausible-looking stub: without one, `npm install` creates
# no `node_modules` and there is nothing for `.gitignore` to exclude.
#
# Entry dates are fixed, so a rebuild produces a byte-identical archive — same
# fixture, same screenshots, on any machine.
#
# Requires: zip (stock macOS). Node is only needed to verify, not to build.
#
set -euo pipefail

cd "$(dirname "$0")"

OUT="markdown-kit.zip"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

mkdir -p "$BUILD/src" "$BUILD/tests"

cat > "$BUILD/.gitignore" <<'EOF'
# Dependencies
node_modules/

# Build output
dist/
*.tsbuildinfo

# Logs
*.log
npm-debug.log*

# Editor / OS
.DS_Store
.idea/
.vscode/
EOF

cat > "$BUILD/LICENSE" <<'EOF'
MIT License

Copyright (c) 2026 the markdown-kit contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

cat > "$BUILD/README.md" <<'EOF'
# markdown-kit

A tiny Markdown renderer with no runtime dependencies. One function in, HTML
out — about 200 lines, no plugin system, no configuration object.

It covers the subset of Markdown that documentation actually uses: headings,
paragraphs, fenced code, blockquotes, lists, and the four inline forms. If you
need tables, footnotes or MDX, use a full CommonMark implementation instead.

## Install

```sh
npm install markdown-kit
```

## Usage

```js
import { render } from 'markdown-kit'

render('# Hello\n\nSome **bold** text.')
// => '<h1>Hello</h1>\n<p>Some <strong>bold</strong> text.</p>'
```

Everything is escaped by default, so rendering untrusted input does not inject
markup:

```js
render('<script>alert(1)</script>')
// => '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>'
```

## API

### `render(markdown)`

Renders a Markdown string to an HTML string.

### `tokenize(markdown)`

Returns the intermediate block tokens, if you would rather emit something other
than HTML. Each token is `{ type, ... }`, where `type` is one of `heading`,
`paragraph`, `code`, `quote` or `list`.

## Supported syntax

| Block        | Written as                    |
| ------------ | ----------------------------- |
| Heading      | `# Title` through `###### h6` |
| Code         | ` ```js ` fenced              |
| Quote        | `> quoted`                    |
| List         | `- item` or `* item`          |
| Paragraph    | anything else                 |

Inline: `**bold**`, `*italic*`, `` `code` `` and `[text](url)`.

## Development

```sh
npm install
npm test        # node --test
npm run build   # bundles to dist/
```

## License

MIT — see [LICENSE](LICENSE).
EOF

cat > "$BUILD/package.json" <<'EOF'
{
  "name": "markdown-kit",
  "version": "0.4.2",
  "description": "A tiny Markdown to HTML renderer with no runtime dependencies.",
  "license": "MIT",
  "type": "module",
  "main": "src/index.js",
  "exports": {
    ".": "./src/index.js"
  },
  "files": [
    "src",
    "README.md",
    "LICENSE"
  ],
  "engines": {
    "node": ">=18"
  },
  "scripts": {
    "build": "esbuild src/index.js --bundle --format=esm --outfile=dist/markdown-kit.js",
    "test": "node --test"
  },
  "devDependencies": {
    "esbuild": "^0.25.0"
  },
  "keywords": [
    "markdown",
    "html",
    "renderer",
    "parser"
  ]
}
EOF

cat > "$BUILD/src/index.js" <<'EOF'
// markdown-kit — the whole public surface.

import { tokenize } from './parser.js'

export { tokenize }

const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }

/** Escapes the characters that would otherwise be read as markup. */
export function escapeHtml(text) {
  return text.replace(/[&<>"]/g, (character) => ESCAPES[character])
}

const PLACEHOLDER = /\u0000(\d+)\u0000/g

/**
 * Renders inline Markdown: links, then the two emphasis forms.
 *
 * Code spans are lifted out into placeholders first and put back last. Running
 * their replacement inline would not be enough — the later emphasis passes walk
 * the whole string, so `` `**verbatim**` `` would come back emphasised.
 */
export function renderInline(text) {
  const spans = []
  const withPlaceholders = escapeHtml(text).replace(/`([^`]+)`/g, (_, code) => {
    spans.push(code)
    return `\u0000${spans.length - 1}\u0000`
  })
  return withPlaceholders
    .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\*([^*]+)\*/g, '<em>$1</em>')
    .replace(PLACEHOLDER, (_, index) => `<code>${spans[index]}</code>`)
}

function renderToken(token) {
  switch (token.type) {
    case 'heading':
      return `<h${token.level}>${renderInline(token.text)}</h${token.level}>`
    case 'code':
      // Code is escaped but never rendered as inline Markdown.
      return token.language
        ? `<pre><code class="language-${token.language}">${escapeHtml(token.text)}</code></pre>`
        : `<pre><code>${escapeHtml(token.text)}</code></pre>`
    case 'quote':
      return `<blockquote>${renderInline(token.text)}</blockquote>`
    case 'list':
      return `<ul>${token.items.map((item) => `<li>${renderInline(item)}</li>`).join('')}</ul>`
    default:
      return `<p>${renderInline(token.text)}</p>`
  }
}

/** Renders a Markdown string to HTML. */
export function render(markdown) {
  return tokenize(markdown).map(renderToken).join('\n')
}

export default render
EOF

cat > "$BUILD/src/parser.js" <<'EOF'
// Block-level scanner. Line based, single pass, no lookbehind: every block
// either opens on its own first line or is a paragraph.

const HEADING = /^(#{1,6})\s+(.*)$/
const FENCE = /^```(\w*)\s*$/
const QUOTE = /^>\s?(.*)$/
const BULLET = /^[-*]\s+(.*)$/

/**
 * Splits Markdown into block tokens.
 *
 * Returns an array of `{ type, ... }`:
 *   { type: 'heading',   level, text }
 *   { type: 'code',      language, text }
 *   { type: 'quote',     text }
 *   { type: 'list',      items }
 *   { type: 'paragraph', text }
 */
export function tokenize(markdown) {
  const lines = String(markdown).replace(/\r\n?/g, '\n').split('\n')
  const tokens = []
  let paragraph = []

  // Paragraphs run until a blank line or a block that opens on its own, so
  // every branch below has to close the one being collected first.
  const flush = () => {
    if (paragraph.length) {
      tokens.push({ type: 'paragraph', text: paragraph.join(' ').trim() })
      paragraph = []
    }
  }

  for (let index = 0; index < lines.length; index++) {
    const line = lines[index]

    const fence = FENCE.exec(line)
    if (fence) {
      flush()
      const body = []
      // Consume through the closing fence; an unterminated fence runs to the
      // end of the input rather than throwing.
      while (++index < lines.length && !FENCE.test(lines[index])) {
        body.push(lines[index])
      }
      tokens.push({ type: 'code', language: fence[1] || null, text: body.join('\n') })
      continue
    }

    if (!line.trim()) {
      flush()
      continue
    }

    const heading = HEADING.exec(line)
    if (heading) {
      flush()
      tokens.push({ type: 'heading', level: heading[1].length, text: heading[2].trim() })
      continue
    }

    const quote = QUOTE.exec(line)
    if (quote) {
      flush()
      tokens.push({ type: 'quote', text: quote[1].trim() })
      continue
    }

    const bullet = BULLET.exec(line)
    if (bullet) {
      flush()
      const items = [bullet[1].trim()]
      // Adjacent bullets are one list.
      while (index + 1 < lines.length && BULLET.test(lines[index + 1])) {
        items.push(BULLET.exec(lines[++index])[1].trim())
      }
      tokens.push({ type: 'list', items })
      continue
    }

    paragraph.push(line.trim())
  }

  flush()
  return tokens
}
EOF

cat > "$BUILD/tests/parser.test.js" <<'EOF'
import assert from 'node:assert/strict'
import { test } from 'node:test'

import { render, renderInline, tokenize } from '../src/index.js'

test('headings carry their level', () => {
  assert.deepEqual(tokenize('### Title'), [{ type: 'heading', level: 3, text: 'Title' }])
  assert.equal(render('# Hello'), '<h1>Hello</h1>')
})

test('consecutive lines join into one paragraph', () => {
  assert.equal(render('one\ntwo'), '<p>one two</p>')
  assert.equal(render('one\n\ntwo'), '<p>one</p>\n<p>two</p>')
})

test('fenced code keeps its language and is not re-parsed', () => {
  const [token] = tokenize('```js\nconst a = **1**\n```')
  assert.equal(token.type, 'code')
  assert.equal(token.language, 'js')
  assert.equal(token.text, 'const a = **1**')
  assert.match(render('```js\na < b\n```'), /<code class="language-js">a &lt; b<\/code>/)
})

test('an unterminated fence runs to the end of the input', () => {
  assert.deepEqual(tokenize('```\nstill open'), [
    { type: 'code', language: null, text: 'still open' },
  ])
})

test('adjacent bullets collapse into one list', () => {
  assert.equal(render('- one\n- two'), '<ul><li>one</li><li>two</li></ul>')
})

test('inline forms nest inside blocks', () => {
  assert.equal(renderInline('**bold** and *italic*'), '<strong>bold</strong> and <em>italic</em>')
  assert.equal(renderInline('[docs](https://example.com)'), '<a href="https://example.com">docs</a>')
})

test('code spans are not scanned for emphasis', () => {
  assert.equal(renderInline('`**verbatim**`'), '<code>**verbatim**</code>')
})

test('markup in the input is escaped', () => {
  assert.equal(render('<script>alert(1)</script>'), '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>')
})

test('blockquotes drop the marker', () => {
  assert.equal(render('> quoted'), '<blockquote>quoted</blockquote>')
})

test('CRLF input is normalised', () => {
  assert.equal(render('one\r\n\r\ntwo'), '<p>one</p>\n<p>two</p>')
})
EOF

# Fixed dates: a checkout has plausible, varied mtimes, and screenshots must not
# read "52 seconds ago". Same values on every rebuild.
touch -t 202603140902 "$BUILD/LICENSE"
touch -t 202604021547 "$BUILD/.gitignore"
touch -t 202606111038 "$BUILD/src/parser.js"
touch -t 202606111112 "$BUILD/tests/parser.test.js"
touch -t 202606181423 "$BUILD/src/index.js"
touch -t 202607061955 "$BUILD/package.json"
touch -t 202607220831 "$BUILD/README.md"
touch -t 202606181423 "$BUILD/src"
touch -t 202606111112 "$BUILD/tests"

rm -f "$OUT"
# -X: no uid/gid or extended attributes, so the bytes depend only on the content
# and the dates above.
(cd "$BUILD" && zip -q -r -X "$OLDPWD/$OUT" .gitignore LICENSE README.md package.json src tests)

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
