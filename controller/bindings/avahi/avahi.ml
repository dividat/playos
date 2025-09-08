open Lwt

module Service = struct
  type t =
    { service_name : string
    ; service_type : string
    ; interface : string
    }

  (** Decodes an escaped service instance name.

      avahi produces UTF-8 output, but encodes any but a few "known-good" ASCII
      bytes when printing the instance name in the parsable form:

        - [-_a-zA-Z0-9] are printed directly
        - \ and . are escaped with a backslash
        - any other byte value is output as three digit decimal \ddd

      https://github.com/avahi/avahi/blob/2bb03084505fb9e2041ee8083a0ca08f1665f0f5/avahi-common/domain.c#L116

      This decoding function is more lax than it could be and copies
      non-escaped characters directly instead of verifying they are from
      avahi's "direct" range.

  *)
  let unescape_label s =
    let len = String.length s in
    let buf = Buffer.create len in
    let is_digit c = c >= '0' && c <= '9' in
    let rec loop i =
      if i >= len then
        (* Whole string has been processed *)
        Some (Buffer.contents buf)
      else if s.[i] <> '\\' then (
        (* Not an escape sequence, copy the character *)
        Buffer.add_char buf s.[i] ;
        loop (i + 1)
      )
      else if i + 1 < len && (s.[i + 1] = '\\' || s.[i + 1] = '.') then (
        (* Escaped backslash or dot *)
        Buffer.add_char buf s.[i + 1] ;
        loop (i + 2)
      )
      else if
        i + 3 < len
        && is_digit s.[i + 1]
        && is_digit s.[i + 2]
        && is_digit s.[i + 3]
      then
        (* Three-digit escape string '\ddd' *)
        match int_of_string_opt (String.sub s (i + 1) 3) with
        | Some code when code <= 255 ->
            Buffer.add_char buf (Char.chr code) ;
            loop (i + 4)
        | _ ->
            (* Out of range code *)
            None
      else
        (* Malformed escape sequence *)
        None
    in
    loop 0

  let parse_service line =
    match String.split_on_char ';' line with
    (* e.g. +;eth1;IPv4;MyPrinter;_myprinter._tcp;local *)
    | [ _; iface; _; name; stype; _ ] ->
        Some
          { service_name = unescape_label name |> Option.value ~default:name
          ; service_type = stype
          ; interface = iface
          }
    | _ ->
        None

  (* Gets all announced services of any type known to avahi at time of call.

     We race with a timeout because avahi is rumored to block even when
     only the cached table is requested: https://github.com/avahi/avahi/issues/264

     In case of timeout we return an empty list of services.

   *)
  let get_all ?(timeout_seconds = 0.2) () =
    let cmd =
      [| "/run/current-system/sw/bin/avahi-browse"
       ; "--all"
       ; "--parsable"
       ; "--cache" (* print cache and exit immediately *)
      |]
    in
    let query =
      ("", cmd)
      |> Lwt_process.pread_lines
      |> Lwt_stream.to_list
      >|= List.filter_map parse_service
    in
    let timeout = Lwt_unix.sleep timeout_seconds >|= fun () -> [] in
    Lwt.pick [ query; timeout ]
end
