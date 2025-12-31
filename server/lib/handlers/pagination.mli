module Pagination : sig
  type t = { page : int; per_page : int }

  val pagination_extractor : t Tapak.Router.extractor
end
