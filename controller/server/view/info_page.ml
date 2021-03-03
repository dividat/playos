open Tyxml
open Info

let definition term description =
  [%html {|
    <dt class="d-Definitions__Term">|} [ Html.txt term ] {|</dt><!--
    --><dd class="d-Definitions__Description">|} [ Html.txt description ] {|</dd>
  |} ]

let html infos =
  let definitions =
    (definition "Version" infos.version)
    @ (definition "Update URL" infos.update_url)
    @ (definition "Kiosk URL" infos.kiosk_url)
    @ (definition "Machine ID" infos.machine_id)
    @ (definition "ZeroTier address" (infos.zerotier_address|> Option.value ~default:"—"))
    @ (definition "Local time" infos.local_time)
  in
  [%html {|
    <div>
      <h1 class="d-Title">Information</h1>
      <dl>|} definitions {|</dl>
    </div>
  |} ]
