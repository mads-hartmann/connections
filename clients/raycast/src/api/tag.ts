export interface Tag {
  id: number;
  name: string;
}

export interface TagsResponse {
  data: Tag[];
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export function listUrl({ page, query }: { page: number; query?: string }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  if (query) {
    params.set("query", query);
  }
  return `http://localhost:8080/tags?${params.toString()}`;
}
