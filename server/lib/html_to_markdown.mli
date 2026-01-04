(** HTML to Markdown conversion with content extraction *)

val convert : title:string -> string -> string
(** [convert ~title html] extracts the main content from HTML and converts it to Markdown.
    Uses the article title to help locate the content area when common selectors fail. *)
