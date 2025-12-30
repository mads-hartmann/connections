val merge_author :
  microformats:Extract_microformats.h_card option ->
  json_ld:Extract_json_ld.person option ->
  opengraph:string option ->
  twitter:string option ->
  html_meta:string option ->
  rel_me:string list ->
  Types.Author.t option

val merge_content :
  microformats:Extract_microformats.h_entry option ->
  json_ld:Extract_json_ld.article option ->
  opengraph:Extract_opengraph.t ->
  twitter:Extract_twitter.t ->
  html_meta:Extract_html_meta.t ->
  author:Types.Author.t option ->
  Types.Content.t

val merge_site :
  opengraph:Extract_opengraph.t ->
  html_meta:Extract_html_meta.t ->
  Types.Site.t
