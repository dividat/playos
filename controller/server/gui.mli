val start :
  port : int
  -> systemd : Systemd.Manager.t
  -> health_s : Health.state Lwt_react.S.t
  -> update_s : Update.state Lwt_react.S.t
  -> rauc : Rauc.t
  -> connman : Connman.Manager.t
  -> unit Lwt.t
