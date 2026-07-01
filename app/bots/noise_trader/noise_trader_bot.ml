module Config = struct
  type t =
    { symbols : Symbol.t list
    ; mean_size : int
    ; tick_change : float
    }
end
