open Tyxml.Html
open Lwt

let log_src = Logs.Src.create "licensing_page"

let tool ~name ~license_name ~license_content content =
  div
    [ h2 ~a:[ a_class [ "d-Title" ] ] [ txt name ]
    ; div content
    ; details
      ~a:[ a_class [ "d-Licensing__Details" ] ]
      (summary [ txt license_name ])
      [ pre ~a: [ a_class [ "d-Preformatted" ] ]  [ txt license_content ] ]
    ]

let read_license key =
  Util.read_from_file log_src (Util.resource_path (Fpath.v ("licenses/" ^ key)))

let html =
  let%lwt playos_license = read_license "PLAYOS" in
  let%lwt nixpkgs_license = read_license "NIXPKGS" in
  let%lwt feather_license = read_license "FEATHER" in
  let%lwt qt6_license = read_license "QT6" in
  Lwt.return (Page.html
    ~current_page:Page.Licensing
    ~header:(Page.header_title
      ~icon:Icon.copyright
      [ txt "Licensing" ])
    (div
      [ tool
        ~name:"PlayOS"
        ~license_name:"MIT License"
        ~license_content:playos_license
        [ p
          ~a:[ a_class [ "d-Paragraph" ] ]
          [ txt "Source code is available at "
          ; a
            ~a:[ a_class [ "d-Licensing__Link" ] ]
            [ txt "http://github.com/dividat/playos" ]
          ; txt ", with instructions to build and modify the software."
          ]
        ]
      ; tool
        ~name:"Nixpkgs"
        ~license_name:"MIT License"
        ~license_content:nixpkgs_license
        []
      ; tool
        ~name:"Feather"
        ~license_name:"MIT License"
        ~license_content:feather_license
        []
      ; tool
        ~name:"Qt6"
        ~license_name:"GNU Lesser General Public License v3.0"
        ~license_content:qt6_license
        []
      ]))
