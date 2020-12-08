(** Proxy validation and pretty print.*)

type credentials =
  { user: string
  ; password: string
  }

type t =
  { credentials: credentials option
  ; host: string
  ; port: int
  }

val validate : string -> t option
(** [validate str] returns [t] if [str] is valid.

    Valid proxies:

      - Use the http scheme,
      - have a host and a port,
      - may have credentials.

    Example of valid proxies:

      - http://127.0.0.1:1234.
      - http://user:password@host.com:8888.*)

val to_string : ?hide_password:bool -> t -> string
(** [to_string t] returns a string from [t].

    if [hide_password] is true, the password is replaced by a fixed number of
    stars in the output.*)
