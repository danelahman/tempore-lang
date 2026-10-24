module Location = Utils.Location

let scan ~filename source =
  let lexbuf = Lexing.from_string source in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
  let lexer = Lexer.tokens () in
  let next () =
    let token = lexer lexbuf in
    (token, Location.of_lexbuf lexbuf)
  in
  (* The location of the last element and the chains, from the element
     [element] on, after the elements [chain] of its chain and the chains
     [chains] before it, both reversed. *)
  let rec chains_after (element, at) chain chains =
    let chain = { Location.it = element; at } :: chain in
    match next () with
    | Token.INFIXOP0 "<", _ -> first_element chain chains
    | Token.COMMA, _ -> first_element [] (List.rev chain :: chains)
    | _ -> (at, List.rev (List.rev chain :: chains))
  and first_element chain chains =
    match next () with
    | Token.UNAME element, at -> chains_after (element, at) chain chains
    | _ -> raise Exit
  in
  match next () with
  | Token.LNAME "grade", start -> (
      match next () with
      | Token.LNAME "lattice", _ -> (
          match first_element [] [] with
          | stop, chains -> Some (Location.merge start stop, chains)
          | exception (Exit | Utils.Error.Error _) -> None)
      | _ | (exception Utils.Error.Error _) -> None)
  | _ | (exception Utils.Error.Error _) -> None
