val start :
  port : int
  -> shutdown : (unit -> unit Lwt.t)
  -> health_s : Health.state Lwt_react.S.t
  -> update_s : Update.state Lwt_react.S.t
  -> rauc : Rauc.t
  -> connman : Connman.Manager.t
  -> proxy : Proxy.t option
  -> internet: Network.Internet.state Lwt_react.S.t
  -> unit Lwt.t
