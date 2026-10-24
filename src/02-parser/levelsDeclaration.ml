module Location = Utils.Location

let scan ~filename source =
  let lexbuf = Lexing.from_string source in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
  let lexer = Lexer.tokens () in
  let next () =
    let token = lexer lexbuf in
    (token, Location.of_lexbuf lexbuf)
  in
  (* The location of the last level and the chains, from the level [level]
     on, after the levels [chain] of its chain and the chains [chains] before
     it, both reversed. *)
  let rec chains_after (level, at) chain chains =
    let chain = { Location.it = level; at } :: chain in
    match next () with
    | Token.INFIXOP0 "<", _ -> first_level chain chains
    | Token.COMMA, _ -> first_level [] (List.rev chain :: chains)
    | _ -> (at, List.rev (List.rev chain :: chains))
  and first_level chain chains =
    match next () with
    | Token.UNAME level, at -> chains_after (level, at) chain chains
    | _ -> raise Exit
  in
  match next () with
  | Token.LNAME "levels", start -> (
      match first_level [] [] with
      | stop, chains -> Some (Location.merge start stop, chains)
      | exception (Exit | Utils.Error.Error _) -> None)
  | _ | (exception Utils.Error.Error _) -> None
