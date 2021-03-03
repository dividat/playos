open Tyxml

type menu =
  | Info
  | Network
  | Localization
  | Shutdown

let link menu =
  match menu with
  | Info -> "/info"
  | Network -> "/network"
  | Localization -> "/localization"
  | Shutdown -> "/shutdown"

let icon menu =
  match menu with
  | Info -> "/static/info.svg"
  | Network -> "/static/wifi.svg"
  | Localization -> "/static/world.svg"
  | Shutdown -> "/static/power.svg"

let alt menu =
  match menu with
  | Info -> "Information"
  | Network -> "Network"
  | Localization -> "Localization"
  | Shutdown -> "Shutdown"

let menu_item menu_selection m =
  let class_ = "d-Menu__Item" ::
    (if m = menu_selection then [ "d-Menu__Item--Active" ] else [])
  in
  [%html {|
    <div class=|} class_ {|>
      <a href=|} (link m) {|>
        <img class="d-Menu__ItemIcon" src=|} (icon m) {| alt=|} (alt m) {|>
      </a>
    </div>
  |} ]

let page menu_selection content =
  [%html {|
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>PlayOS Controller</title>
        <link rel="stylesheet" href="/static/reset.css">
        <link rel="stylesheet" href="/static/style.css">
      </head>

      <body class="d-Container">
        <header class="d-Header">
        </header>

        <nav class="d-Menu">
          |}
            ([ Info; Network; Localization; Shutdown ]
              |> List.map (menu_item menu_selection))
          {|
        </nav>

          <main class="d-Content">
            |} [ content ] {|
          </main>

          <footer class="d-Footer">
            <a href="/changelog" class="d-Footer__Link">changelog</a>
            <a href="/status" class="d-Footer__Link">system status</a>
          </footer>
      </body>
    </html>
  |} ]
