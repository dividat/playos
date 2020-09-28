type status = {
  address: string
}

val get_status : proxy: Uri.t option -> (status, exn) Lwt_result.t
