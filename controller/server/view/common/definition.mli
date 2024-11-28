val list :
     ?a:[< Html_types.dl_attrib > `Class ] Tyxml.Html.attrib list
  -> [< Html_types.dl_content_fun ] Tyxml.Html.elt Tyxml.Html.list_wrap
  -> [> Html_types.dl ] Tyxml.Html.elt

val term :
     ?a:[< Html_types.dt_attrib > `Class ] Tyxml.Html.attrib list
  -> [< Html_types.dt_content_fun ] Tyxml.Html.elt Tyxml.Html.list_wrap
  -> [> Html_types.dt ] Tyxml.Html.elt

val description :
     ?a:[< Html_types.dt_attrib > `Class ] Tyxml.Html.attrib list
  -> [< Html_types.dt_content_fun ] Tyxml.Html.elt Tyxml.Html.list_wrap
  -> [> Html_types.dt ] Tyxml.Html.elt
