import { getServerUrl } from "./config";

export interface Tag {
  id: number;
  name: string;
}

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
  tags: Tag[];
  og_title: string | null;
  og_description: string | null;
  og_image: string | null;
  og_site_name: string | null;
  og_fetched_at: string | null;
  og_fetch_error: string | null;
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
  return `${getServerUrl()}/feeds/${feedId}/articles?${params.toString()}`;
}

export function listAllUrl({ page, unread, query }: { page: number; unread?: boolean; query?: string }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  if (unread) {
    params.set("unread", "true");
  }
  if (query) {
    params.set("query", query);
  }
  return `${getServerUrl()}/articles?${params.toString()}`;
}

export function listByTagUrl({ tag, page }: { tag: string; page: number }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20", tag });
  return `${getServerUrl()}/articles?${params.toString()}`;
}

export async function markArticleRead(id: number, read: boolean): Promise<Article> {
  const response = await fetch(`${getServerUrl()}/articles/${id}/read`, {
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
  const response = await fetch(`${getServerUrl()}/feeds/${feedId}/articles/mark-all-read`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to mark all articles as read");
  }
  return response.json();
}

export async function refreshArticleMetadata(id: number): Promise<Article> {
  const response = await fetch(`${getServerUrl()}/articles/${id}/refresh-metadata`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to refresh article metadata");
  }
  return response.json();
}
