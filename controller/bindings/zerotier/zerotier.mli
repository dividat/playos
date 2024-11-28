type status = { address : string }

val get_status : unit -> (status, exn) Lwt_result.t
