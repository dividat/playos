open Alcotest

let decode input expected () =
  check (option string) "same string" (Some expected)
    (Avahi.Service.unescape_label input)

let fail input () =
  check (option string) "no output" None (Avahi.Service.unescape_label input)

let suite =
  [ ("empty string", `Quick, decode "" "")
  ; ("no escape strings", `Quick, decode "printer_foo" "printer_foo")
  ; ("leading space", `Quick, decode "\\032start" " start")
  ; ("space", `Quick, decode "ho\\032ho" "ho ho")
  ; ("closing space", `Quick, decode "\\032start" " start")
  ; ("exclaim", `Quick, decode "warn\\033" "warn!")
  ; ("slash", `Quick, decode "path\\047to" "path/to")
  ; ("emoji", `Quick, decode "Hi\\032\\240\\159\\152\\132" "Hi 😄")
  ; ("dot is de-escaped", `Quick, decode "foo\\.bar" "foo.bar")
  ; ("backslash is de-escaped", `Quick, decode "\\\\" "\\")
  ; ("escaped alnum are accepted", `Quick, decode "\\065\\066\\049" "AB1")
  ; ("escaped dot is accepted", `Quick, decode "foo\\046bar" "foo.bar")
  ; ("unescaped space is accepted", `Quick, decode " " " ")
  ; ("illegal code fails", `Quick, fail "\\333")
  ; ("single backslash fails", `Quick, fail "\\")
  ]

let () = Alcotest.run "Avahi" [ ("decode_instance_name", suite) ]
