let combine h h' = (h * 65599) + h'
let list hash xs = List.fold_left (fun h x -> combine h (hash x)) 0 xs
