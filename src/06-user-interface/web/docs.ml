open Vdom
module Block = Cmarkit.Block
module Inline = Cmarkit.Inline

(* The documentation pages are rendered from the repository's own READMEs
   rather than from copies, so that they cannot fall behind the language they
   describe. The modules Readme_md, Arduino_readme_md and Opentrons_readme_md
   are generated from them; check the dune file for details. *)
let source = function
  | WebDocPages.Main -> Readme_md.contents
  | WebDocPages.Arduino -> Arduino_readme_md.contents
  | WebDocPages.Opentrons -> Opentrons_readme_md.contents

(* Locations are kept so that a construct this renderer does not know about can
   still be shown as the Markdown it was written as, and heading identifiers so
   that the table of contents has something to link to. *)
let parse page =
  Cmarkit.Doc.of_string ~heading_auto_ids:true ~locs:true (source page)

(* What the rendering of a page refers to: the page, for the resolution of its
   links, its source, for the text of unsupported constructs, and its link
   definitions. *)
type context = {
  page : WebDocPages.page;
  text : string;
  defs : Cmarkit.Label.defs;
}

(* The repository the README's relative links point into; the web interface is
   served from elsewhere, so they cannot be followed as they stand. *)
let repository = "https://github.com/danelahman/tempore-lang/blob/main/"

(* The comment that marks a README section as belonging to the repository only. *)
let skip_marker = "web-skip"

(* The source text a node was parsed from, empty when it carries no location. *)
let literal_source ctx meta =
  let loc = Cmarkit.Meta.textloc meta in
  if Cmarkit.Textloc.is_none loc || Cmarkit.Textloc.is_empty loc then ""
  else
    let first = Cmarkit.Textloc.first_byte loc in
    let last =
      min (Cmarkit.Textloc.last_byte loc) (String.length ctx.text - 1)
    in
    if first > last then "" else String.sub ctx.text first (last - first + 1)

let block_source ctx b =
  literal_source ctx (Block.meta ~ext:(fun _ -> Cmarkit.Meta.none) b)

let inline_source ctx i =
  literal_source ctx (Inline.meta ~ext:(fun _ -> Cmarkit.Meta.none) i)

let line_text lines =
  String.concat "\n" (List.map Cmarkit.Block_line.to_string lines)

(* An HTML comment carries no content of its own, so it is dropped rather than
   shown as unsupported source. *)
let is_html_comment lines =
  let s = String.trim (line_text lines) in
  String.starts_with ~prefix:"<!--" s && String.ends_with ~suffix:"-->" s

(* The identifier cmarkit derives from a heading's text; a heading without one
   is rendered plain, since an anchor that leads nowhere is worse than none. *)
let heading_id h =
  match Block.Heading.id h with
  | Some (`Auto s | `Id s) -> Some s
  | None -> None

let external_link href content =
  elt "a"
    ~a:
      [
        attr "href" href;
        attr "target" "_blank";
        attr "rel" "noopener noreferrer";
      ]
    content

let message_link msg content =
  elt "a"
    ~a:[ attr "href" "#"; onclick ~prevent_default:() (fun _ -> msg) ]
    content

(* The kinds of destination: a heading of the page, which is followed in place;
   another documentation page, which is shown instead; a bundled example, which
   is loaded into the editor; another path in the repository, which is resolved
   against GitHub; and an absolute URL, which is left alone. Every one of them
   is an <a>, so that the page stays navigable by keyboard. *)
let link_to page dest content =
  match WebDocPages.resolve ~from:page dest with
  | WebDocPages.Anchor id -> elt "a" ~a:[ attr "href" ("#" ^ id) ] content
  | WebDocPages.Page (target, heading) ->
      message_link (Model.ShowDocs (target, heading)) content
  | WebDocPages.External href -> external_link href content
  | WebDocPages.Repository path -> (
      match Model.example_of_path path with
      | Some (group, e) ->
          message_link (Model.EditMsg (Model.LoadExample (group, e))) content
      | None -> external_link (repository ^ path) content)

let link_destination defs link =
  let definition =
    match Inline.Link.reference link with
    | `Inline (ld, _) -> Some ld
    | `Ref _ -> (
        match Inline.Link.reference_definition defs link with
        | Some (Cmarkit.Link_definition.Def (ld, _)) -> Some ld
        | _ -> None)
  in
  Option.bind definition (fun ld ->
      Option.map fst (Cmarkit.Link_definition.dest ld))

let rec inline ctx i =
  match i with
  | Inline.Text (t, _) -> [ text t ]
  | Inline.Inlines (is, _) -> List.concat_map (inline ctx) is
  | Inline.Code_span (cs, _) ->
      [ elt "code" [ text (Inline.Code_span.code cs) ] ]
  | Inline.Emphasis (e, _) ->
      [ elt "em" (inline ctx (Inline.Emphasis.inline e)) ]
  | Inline.Strong_emphasis (e, _) ->
      [ elt "strong" (inline ctx (Inline.Emphasis.inline e)) ]
  | Inline.Break (b, _) -> (
      (* A soft break is a line break in the source only, which the browser
         collapses into the space the text needs. *)
      match Inline.Break.type' b with
      | `Hard -> [ elt "br" [] ]
      | `Soft -> [ text "\n" ])
  | Inline.Autolink (a, _) ->
      let target = fst (Inline.Autolink.link a) in
      let dest =
        if Inline.Autolink.is_email a then "mailto:" ^ target else target
      in
      [ link_to ctx.page dest [ text target ] ]
  | Inline.Link (l, _) -> (
      let content = inline ctx (Inline.Link.text l) in
      match link_destination ctx.defs l with
      | None -> content
      | Some dest -> [ link_to ctx.page dest content ])
  | i -> ( match inline_source ctx i with "" -> [] | s -> [ text s ])

(* The document is a tree of Blocks nodes, which say nothing themselves; a flat
   list of blocks is what both the section filter and list items need. *)
let rec flatten b =
  match b with Block.Blocks (bs, _) -> List.concat_map flatten bs | b -> [ b ]

let rec block ctx b =
  match b with
  | Block.Blocks (bs, _) -> List.concat_map (block ctx) bs
  | Block.Blank_line _ -> []
  | Block.Paragraph (p, _) ->
      [ elt "p" (inline ctx (Block.Paragraph.inline p)) ]
  | Block.Heading (h, _) ->
      let a =
        match heading_id h with Some id -> [ attr "id" id ] | None -> []
      in
      [
        elt ~a
          (Printf.sprintf "h%d" (Block.Heading.level h))
          (inline ctx (Block.Heading.inline h));
      ]
  | Block.Code_block (cb, _) ->
      let code =
        String.concat ""
          (List.map
             (fun l -> Cmarkit.Block_line.to_string l ^ "\n")
             (Block.Code_block.code cb))
      in
      [ elt "pre" [ elt "code" [ text code ] ] ]
  | Block.Block_quote (bq, _) ->
      [ elt "blockquote" (block ctx (Block.Block_quote.block bq)) ]
  | Block.List (l, _) ->
      let tight = Block.List'.tight l in
      let items =
        List.map
          (fun (i, _) -> elt "li" (item ctx ~tight i))
          (Block.List'.items l)
      in
      [
        (match Block.List'.type' l with
        | `Unordered _ -> elt "ul" items
        | `Ordered (start, _) ->
            elt "ol"
              ~a:(if start = 1 then [] else [ int_attr "start" start ])
              items);
      ]
  | Block.Thematic_break _ -> [ elt "hr" [] ]
  | Block.Html_block (lines, _) when is_html_comment lines -> []
  | b -> (
      (* Anything this renderer does not know about is shown as its own source,
         so that it is noticed and handled rather than silently lost. *)
      match block_source ctx b with
      | "" -> []
      | s -> [ elt "pre" [ elt "code" [ text s ] ] ])

(* CommonMark drops the paragraph around an item's text in a tight list, which
   is what keeps the items of such a list from being spaced apart. *)
and item ctx ~tight i =
  let blocks = flatten (Block.List_item.block i) in
  if not tight then List.concat_map (block ctx) blocks
  else
    List.concat_map
      (function
        | Block.Paragraph (p, _) -> inline ctx (Block.Paragraph.inline p)
        | b -> block ctx b)
      blocks

let rec first_content = function
  | Block.Blank_line _ :: rest -> first_content rest
  | b :: _ -> Some b
  | [] -> None

(* A heading is marked for skipping by an HTML comment naming [skip_marker]
   right under it. *)
let marked_skip blocks =
  match first_content blocks with
  | Some (Block.Html_block (lines, _)) ->
      is_html_comment lines
      && Widgets.contains ~sub:skip_marker (line_text lines)
  | _ -> false

(* A section runs until the next heading that is no deeper, so skipping one
   also skips the subsections under it. *)
let rec skip_section level = function
  | Block.Heading (h, _) :: _ as blocks when Block.Heading.level h <= level ->
      blocks
  | _ :: rest -> skip_section level rest
  | [] -> []

(* Everything is kept but the marked sections and, on the main page, the
   level-1 heading, which is the logo the page already shows; a section added
   to a README therefore appears here without this module being touched. *)
let rec filter ~title = function
  | [] -> []
  | (Block.Heading (h, _) as b) :: rest ->
      let level = Block.Heading.level h in
      if level = 1 && not title then filter ~title rest
      else if marked_skip rest then filter ~title (skip_section level rest)
      else b :: filter ~title rest
  | b :: rest -> b :: filter ~title rest

(* A heading is listed by its text alone: a link span in it would nest inside
   the entry's own link, which is not valid HTML. *)
let plain_text i =
  String.concat " "
    (List.map (String.concat "")
       (Cmarkit.Inline.to_plain_text
          ~ext:(fun ~break_on_soft:_ _ -> Cmarkit.Inline.empty)
          ~break_on_soft:false i))

(* The entries are read off the same blocks the page renders, so the contents
   cannot come to list a section that is not shown, or miss one that is. *)
let headings blocks =
  List.filter_map
    (function
      | Block.Heading (h, _) ->
          let level = Block.Heading.level h in
          if level = 2 || level = 3 then
            Option.map
              (fun id -> (level, id, plain_text (Block.Heading.inline h)))
              (heading_id h)
          else None
      | _ -> None)
    blocks

(* The level-3 headings that follow a level-2 one belong under it. *)
let rec subsections acc = function
  | ((3, _, _) as entry) :: rest -> subsections (entry :: acc) rest
  | rest -> (List.rev acc, rest)

let rec contents_items page = function
  | [] -> []
  | (level, id, title) :: rest ->
      let entry = link_to page ("#" ^ id) [ text title ] in
      if level = 2 then
        let subs, rest = subsections [] rest in
        let nested =
          match subs with
          | [] -> []
          | subs -> [ elt "ul" (contents_items page subs) ]
        in
        elt "li" (entry :: nested) :: contents_items page rest
      else elt "li" [ entry ] :: contents_items page rest

(* A page prepared for rendering: the context of its blocks, the blocks of its
   README shown, and the entries of its table of contents. *)
type prepared = {
  ctx : context;
  blocks : Block.t list;
  entries : (int * string * string) list;
}

let prepare page =
  let doc = parse page in
  let blocks =
    filter ~title:(page <> WebDocPages.Main) (flatten (Cmarkit.Doc.block doc))
  in
  {
    ctx = { page; text = source page; defs = Cmarkit.Doc.defs doc };
    blocks;
    entries = headings blocks;
  }

(* Each page is parsed once, when it is first shown. *)
let cache = List.map (fun page -> (page, lazy (prepare page))) WebDocPages.all
let prepared page = Lazy.force (List.assoc page cache)

(* The README rendered, and its table of contents. [view] passes both to
   [Vdom.memo], which renders them once for as long as the page is shown. *)
let readme page =
  let { ctx; blocks; _ } = prepared page in
  div ~a:[ class_ "content" ] (List.concat_map (block ctx) blocks)

let contents_menu page =
  elt "ul"
    ~a:[ class_ "menu-list" ]
    (contents_items page (prepared page).entries)

(* The pages, one tab each, the tab of [page] active. *)
let tabs page =
  elt "p"
    ~a:[ class_ "panel-tabs" ]
    (List.map
       (fun p ->
         elt "a"
           ~a:
             ((if p = page then [ class_ "is-active" ] else [])
             @ [
                 attr "href" "#";
                 attr "title" (WebDocPages.title p);
                 onclick ~prevent_default:() (fun _ -> Model.ShowDocs (p, None));
               ])
           [ text (WebDocPages.label p) ])
       WebDocPages.all)

(* Bulma's [menu-list] indents a nested list and lights one entry at a time.
   The body is padded by hand to the measure of a [panel-block] rather than
   being one, since a panel block lights all of its contents at once. *)
let contents page ~action =
  let menu =
    match (prepared page).entries with
    | [] -> []
    | _ :: _ ->
        [ div ~a:[ class_ "px-3 py-2" ] [ Vdom.memo contents_menu page ] ]
  in
  [ Widgets.panel ~action "Contents" (Vdom.memo tabs page :: menu) ]

(** The documentation view showing [page]: the blocks of its main column, the
    README of [page] rendered from its Markdown source, and those of its side
    column, the tabs of the pages and a table of contents of the README. *)
let view page action = ([ Vdom.memo readme page ], contents page ~action)
