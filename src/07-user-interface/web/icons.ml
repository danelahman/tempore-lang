open Vdom

(* The Octicon of the path [path], 16 pixels square. *)
let octicon path =
  svg_elt "svg"
    ~a:
      [
        attr "viewBox" "0 0 16 16";
        attr "width" "16";
        attr "height" "16";
        attr "aria-hidden" "true";
      ]
    [ svg_elt "path" ~a:[ attr "fill" "currentColor"; attr "d" path ] [] ]

let book =
  octicon
    "M0 1.75A.75.75 0 0 1 .75 1h4.253c1.227 0 2.317.59 3 1.501A3.744 3.744 0 0 \
     1 11.006 1h4.245a.75.75 0 0 1 .75.75v10.5a.75.75 0 0 1-.75.75h-4.507a2.25 \
     2.25 0 0 0-1.591.659l-.622.621a.75.75 0 0 1-1.06 0l-.622-.621A2.25 2.25 0 \
     0 0 5.258 13H.75a.75.75 0 0 1-.75-.75Zm7.251 \
     10.324.004-5.073-.002-2.253A2.25 2.25 0 0 0 5.003 2.5H1.5v9h3.757a3.75 \
     3.75 0 0 1 1.994.574ZM8.755 4.75l-.004 7.322a3.752 3.752 0 0 1 \
     1.992-.572H14.5v-9h-3.495a2.25 2.25 0 0 0-2.25 2.25Z"

let code =
  octicon
    "m11.28 3.22 4.25 4.25a.75.75 0 0 1 0 1.06l-4.25 4.25a.749.749 0 0 \
     1-1.275-.326.749.749 0 0 1 .215-.734L13.94 8l-3.72-3.72a.749.749 0 0 1 \
     .326-1.275.749.749 0 0 1 .734.215Zm-6.56 0a.751.751 0 0 1 \
     1.042.018.751.751 0 0 1 .018 1.042L2.06 8l3.72 3.72a.749.749 0 0 1-.326 \
     1.275.749.749 0 0 1-.734-.215L.47 8.53a.75.75 0 0 1 0-1.06Z"

let link =
  octicon
    "m7.775 3.275 1.25-1.25a3.5 3.5 0 1 1 4.95 4.95l-2.5 2.5a3.5 3.5 0 0 \
     1-4.95 0 .751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018 1.998 1.998 0 \
     0 0 2.83 0l2.5-2.5a2.002 2.002 0 0 0-2.83-2.83l-1.25 1.25a.751.751 0 0 \
     1-1.042-.018.751.751 0 0 1-.018-1.042Zm-4.69 9.64a1.998 1.998 0 0 0 2.83 \
     0l1.25-1.25a.751.751 0 0 1 1.042.018.751.751 0 0 1 .018 1.042l-1.25 \
     1.25a3.5 3.5 0 1 1-4.95-4.95l2.5-2.5a3.5 3.5 0 0 1 4.95 0 .751.751 0 0 \
     1-.018 1.042.751.751 0 0 1-1.042.018 1.998 1.998 0 0 0-2.83 0l-2.5 \
     2.5a1.998 1.998 0 0 0 0 2.83Z"

(* The stroke of the path [path] under the classes [cls]. *)
let check_mark cls path =
  svg_elt "svg"
    ~a:
      [
        class_ ("check-status-mark " ^ cls);
        attr "viewBox" "0 0 16 16";
        attr "aria-hidden" "true";
      ]
    [
      svg_elt "path"
        ~a:
          [
            attr "d" path;
            attr "fill" "none";
            attr "stroke" "currentColor";
            attr "stroke-width" "2.2";
            attr "stroke-linecap" "round";
            attr "stroke-linejoin" "round";
          ]
        [];
    ]

let tick cls = check_mark cls "M3 8.6l3.3 3.2L13 4.6"
let cross cls = check_mark cls "M4.5 4.5l7 7M11.5 4.5l-7 7"

let pipette =
  svg_elt "svg"
    ~a:
      [
        attr "viewBox" "0 0 16 16";
        attr "width" "16";
        attr "height" "16";
        attr "aria-hidden" "true";
      ]
    [
      svg_elt "g"
        ~a:
          [
            attr "transform" "rotate(45 8 8)";
            attr "fill" "none";
            attr "stroke" "currentColor";
            attr "stroke-width" "1.4";
            attr "stroke-linecap" "round";
            attr "stroke-linejoin" "round";
          ]
        [
          svg_elt "path"
            ~a:
              [
                attr "d"
                  "M6.3 1.2h3.4M8 1.2v2.3M6 3.5h4v6H6zM6.4 9.5 8 14l1.6-4.5";
              ]
            [];
        ];
      svg_elt "circle"
        ~a:
          [
            attr "cx" "3.1";
            attr "cy" "14.6";
            attr "r" "0.9";
            attr "fill" "currentColor";
          ]
        [];
    ]

let chip =
  svg_elt "svg"
    ~a:
      [
        attr "viewBox" "0 0 16 16";
        attr "width" "16";
        attr "height" "16";
        attr "aria-hidden" "true";
      ]
    [
      svg_elt "g"
        ~a:
          [
            attr "fill" "none";
            attr "stroke" "currentColor";
            attr "stroke-width" "1.4";
            attr "stroke-linecap" "round";
            attr "stroke-linejoin" "round";
          ]
        [
          svg_elt "rect"
            ~a:
              [
                attr "x" "4";
                attr "y" "4";
                attr "width" "8";
                attr "height" "8";
                attr "rx" "1";
              ]
            [];
          svg_elt "path"
            ~a:
              [
                attr "d"
                  "M6 4V1.5M10 4V1.5M6 14.5V12M10 14.5V12M4 6H1.5M4 \
                   10H1.5M14.5 6H12M14.5 10H12";
              ]
            [];
        ];
      svg_elt "circle"
        ~a:
          [
            attr "cx" "6.4";
            attr "cy" "6.4";
            attr "r" "0.8";
            attr "fill" "currentColor";
          ]
        [];
    ]

let github =
  svg_elt "svg"
    ~a:
      [
        attr "viewBox" "0 0 16 16";
        attr "width" "20";
        attr "height" "20";
        attr "aria-hidden" "true";
      ]
    [
      svg_elt "path"
        ~a:
          [
            attr "fill" "currentColor";
            attr "d"
              "M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 \
               7.59.4.07.55-.17.55-.38 \
               0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 \
               1.08.58 1.23.82.72 1.21 1.87.87 \
               2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 \
               0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 \
               2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 \
               2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 \
               3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 \
               1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 \
               8c0-4.42-3.58-8-8-8z";
          ]
        [];
    ]
