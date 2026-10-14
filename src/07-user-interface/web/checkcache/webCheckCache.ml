type key = {
  source : string;
  grades : string;
  use_stdlib : bool;
  declared : BackendRegistry.source list;
}

type 'a t = (key * 'a) option

let empty = None

let find cache key =
  match cache with
  | Some (key', v) when key' = key -> Some v
  | Some _ | None -> None

let checked cache key check =
  match find cache key with
  | Some v -> (Ok v, true, cache)
  | None -> (
      match check () with
      | Ok v -> (Ok v, false, Some (key, v))
      | Error _ as r -> (r, false, cache))
