type full_response = {
  merged : Types.t;
  raw_html_meta : Extract_html_meta.t;
  raw_opengraph : Extract_opengraph.t;
  raw_twitter : Extract_twitter.t;
  raw_json_ld : Extract_json_ld.extracted;
  raw_microformats : Extract_microformats.t;
}

val to_json : Types.t -> Yojson.Safe.t
val full_response_to_json : full_response -> Yojson.Safe.t
