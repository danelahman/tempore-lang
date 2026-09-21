# Third-party notices

Tempore itself is released under the MIT license, see [`LICENSE`](LICENSE).
This file collects the notices of the third-party code that the project's
distributed builds include or load. The relevant artifact is the web
interface (`web/web.bc.js` and `web/index.html`), published to GitHub Pages;
building the project from source instead installs its dependencies as their
own opam packages, each carrying its own license, so no separate notice is
needed for that case.

## Bundled in the web interface (web/web.bc.js)

`web/web.bc.js` is produced by js_of_ocaml from the compiled OCaml program,
so it links the OCaml runtime, the js_of_ocaml runtime, and the OCaml
libraries the web interface uses. A few icons are also drawn directly in the
interface's own code and so end up in the bundle as well.

### OCaml runtime and standard library

Licensed under the GNU Lesser General Public License version 2.1, with the
OCaml linking exception, which permits linking the runtime and standard
library into a program distributed under any license, including this
project's MIT license. The full license text is not reproduced here; see
<https://github.com/ocaml/ocaml/blob/trunk/LICENSE>.

### js_of_ocaml runtime

The js_of_ocaml runtime files that `web.bc.js` links (js_of_ocaml-compiler
6.4.1, by the Ocsigen team; the runtime files are marked "Copyright CNRS
Université Paris Diderot") are likewise licensed under the GNU Lesser
General Public License version 2.1 with a linking exception in the same
style, and the full license text is not reproduced here either; see
<https://github.com/ocsigen/js_of_ocaml/blob/master/LICENSE>. The js_of_ocaml
*compiler*, which turns the compiled OCaml program into `web.bc.js`, is
separately licensed under the GNU General Public License version 2.0 or
later; it is a build-time tool, and its output is not covered by the GPL.

### cmarkit 0.4.0

Used to render this project's README on the web interface's documentation
page. ISC licensed:

```
Copyright (c) 2020 The cmarkit programmers

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

### vdom 0.3

LexiFi's `ocaml-vdom`, which the web interface is built with. MIT licensed:

```
The MIT License (MIT)

Copyright (C) 2000-2023 LexiFi

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### ojs 1.1.7

Part of LexiFi's `gen_js_api`, a dependency of `vdom`. MIT licensed:

```
The MIT License (MIT)

Copyright 2015 by LexiFi.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### GitHub Octicons

Three SVG path datasets are copied into
`src/06-user-interface/web/view.ml` (`book_mark`, `code_mark`, and
`github_mark`) and so end up in the bundle. They are drawn in
`currentColor`, so that they follow the hover styling of the surrounding
link rather than the fixed colour of the original icons: they are recoloured
from the originals, not reproduced unchanged. MIT licensed, Copyright (c)
GitHub Inc.:

```
MIT License

Copyright (c) 2026 GitHub Inc.

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
```

## Loaded by the web page

`web/index.html` loads Bulma 0.9.0 from the jsDelivr CDN
(`https://cdn.jsdelivr.net/npm/bulma@0.9.0/css/bulma.min.css`), the only
external resource the page fetches. The stylesheet is linked at page-load
time, not redistributed with the project. MIT licensed, Copyright (c) 2020
Jeremy Thomas:

```
The MIT License (MIT)

Copyright (c) 2020 Jeremy Thomas

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

## The command-line interpreter

The `tempore` executable links no third-party OCaml library beyond the
OCaml runtime and standard library (`src/06-user-interface/cli/dune` lists
only the project's own libraries). Unlike the web interface, it is not
distributed in built form: users build it themselves with opam, which
installs any dependencies as their own opam packages under their own
licenses.

## Build-time tools

A few tools are used only while building the project and are not part of
either distributed artifact:

- **menhir** (20260209) generates `src/02-parser/grammar.ml` from
  `grammar.mly`. The menhir generator itself is licensed under the GNU
  General Public License version 2.0 only, but the parser it generates does
  not reference MenhirLib, so no LGPL-licensed MenhirLib code is linked into
  either `web.bc.js` or `tempore`.
- **ocamlformat** formats the project's OCaml source.
- **`@vscode/vsce`** packages the VS Code extension in `editors/vscode/`.
