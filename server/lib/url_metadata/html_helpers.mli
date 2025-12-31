val resolve_url : base_url:Uri.t -> string -> string
val attr : string -> Soup.element Soup.node -> string option
val trimmed_text : Soup.element Soup.node -> string option
val select_attr : string -> string -> Soup.soup Soup.node -> string option
val select_text : string -> Soup.soup Soup.node -> string option
