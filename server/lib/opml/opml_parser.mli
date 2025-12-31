type feed_entry = { url : string; title : string option; tags : string list }
type parse_result = { feeds : feed_entry list; errors : string list }

val parse : string -> (parse_result, string) result
