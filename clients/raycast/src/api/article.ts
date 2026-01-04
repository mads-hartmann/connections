import { Alert, confirmAlert } from "@raycast/api";
import { getServerUrl } from "./config";

export interface Tag {
  id: number;
  name: string;
}

export interface Article {
  id: number;
  feed_id: number;
  person_id: number | null;
  person_name: string | null;
  title: string | null;
  url: string;
  published_at: string | null;
  content: string | null;
  author: string | null;
  image_url: string | null;
  created_at: string;
  read_at: string | null;
  read_later_at: string | null;
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

export function listAllUrl({
  page,
  unread,
  readLater,
  query,
}: {
  page: number;
  unread?: boolean;
  readLater?: boolean;
  query?: string;
}) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  if (unread) {
    params.set("unread", "true");
  }
  if (readLater) {
    params.set("read_later", "true");
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

export function listByPersonUrl({ personId, page, unread }: { personId: number; page: number; unread?: boolean }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  if (unread) {
    params.set("unread", "true");
  }
  return `${getServerUrl()}/persons/${personId}/articles?${params.toString()}`;
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

export async function markAllArticlesReadGlobal(): Promise<MarkAllReadResponse> {
  const response = await fetch(`${getServerUrl()}/articles/mark-all-read`, {
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

export async function markReadLater(id: number, readLater: boolean): Promise<Article> {
  const response = await fetch(`${getServerUrl()}/articles/${id}/read-later`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ read_later: readLater }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to update read later status");
  }
  return response.json();
}

export async function deleteArticle(article: Article): Promise<boolean> {
  const confirmed = await confirmAlert({
    title: "Delete Article",
    message: `Are you sure you want to delete "${article.title || "Untitled"}"?`,
    primaryAction: {
      title: "Delete",
      style: Alert.ActionStyle.Destructive,
    },
  });

  if (confirmed) {
    const response = await fetch(`${getServerUrl()}/articles/${article.id}`, {
      method: "DELETE",
    });
    if (!response.ok) {
      throw new Error("Failed to delete article");
    }
    return true;
  }
  return false;
}
