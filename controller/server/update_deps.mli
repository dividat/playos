module type CurlProxyInterface = sig
    val request
      :  ?headers:(string * string) list
      -> ?data:string
      -> ?options:string list
      -> Uri.t
      -> Curl.result Lwt.t
end

type sleep_duration = float (* seconds *)

module type ConfigInterface = sig
    (* time to sleep in seconds until retrying after a (Curl/HTTP) error *)
    val error_backoff_duration: sleep_duration

    (* time to sleep in seconds between checking for available updates *)
    val check_for_updates_interval: sleep_duration

    (* where to fetch updates from *)
    val update_url: string
end

module type UpdateServiceDeps = sig
    module CurlI: CurlProxyInterface
    module ConfigI: ConfigInterface
    module RaucI: Rauc_service.RaucServiceIntf
end
