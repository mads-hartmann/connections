export interface Article {
  id: number;
  feed_id: number;
  title: string | null;
  url: string;
  published_at: string | null;
  content: string | null;
  author: string | null;
  image_url: string | null;
  created_at: string;
  read_at: string | null;
}

export interface ArticlesResponse {
  data: Article[];
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export function listUrl({ feedId, page }: { feedId: number; page: number }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  return `http://localhost:8080/feeds/${feedId}/articles?${params.toString()}`;
}

export async function markArticleRead(id: number, read: boolean): Promise<Article> {
  const response = await fetch(`http://localhost:8080/articles/${id}/read`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ read }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to mark article");
  }
  return response.json();
}

export interface MarkAllReadResponse {
  marked_read: number;
}

export async function markAllArticlesRead(feedId: number): Promise<MarkAllReadResponse> {
  const response = await fetch(`http://localhost:8080/feeds/${feedId}/articles/mark-all-read`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to mark all articles as read");
  }
  return response.json();
}
