val routes :
  connman : Connman.Manager.t
  -> internet: Network.Internet.state Lwt_react.S.t
  -> Opium.App.builder
