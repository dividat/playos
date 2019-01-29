type t =
  { app: string
  ; version: string }

let to_json { app; version } =
  Ezjsonm.(
    dict [
      "app", string app
    ; "version", string version
    ]
  )

let version =
  "2019.1.0-dev"

let get () =
  { app = "PlayOS Controller"
  ; version = version}

