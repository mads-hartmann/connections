import { Alert, confirmAlert } from "@raycast/api";
import { getServerUrl } from "./config";

export interface Tag {
  id: number;
  name: string;
}

export type UriKind = "blog" | "video" | "tweet" | "book" | "site" | "unknown" | "podcast" | "paper";

export interface Uri {
  id: number;
  feed_id: number | null;
  connection_id: number | null;
  connection_name: string | null;
  kind: UriKind;
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

export interface UrisResponse {
  data: Uri[];
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export function listUrl({ feedId, page }: { feedId: number; page: number }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  return `${getServerUrl()}/feeds/${feedId}/uris?${params.toString()}`;
}

export function listAllUrl({
  page,
  unread,
  readLater,
  orphan,
  query,
}: {
  page: number;
  unread?: boolean;
  readLater?: boolean;
  orphan?: boolean;
  query?: string;
}) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  if (unread) {
    params.set("unread", "true");
  }
  if (readLater) {
    params.set("read_later", "true");
  }
  if (orphan) {
    params.set("orphan", "true");
  }
  if (query) {
    params.set("query", query);
  }
  return `${getServerUrl()}/uris?${params.toString()}`;
}

export function listByTagUrl({ tag, page }: { tag: string; page: number }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20", tag });
  return `${getServerUrl()}/uris?${params.toString()}`;
}

export function listByConnectionUrl({
  connectionId,
  page,
  unread,
}: {
  connectionId: number;
  page: number;
  unread?: boolean;
}) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  if (unread) {
    params.set("unread", "true");
  }
  return `${getServerUrl()}/connections/${connectionId}/uris?${params.toString()}`;
}

export async function markUriRead(id: number, read: boolean): Promise<Uri> {
  const response = await fetch(`${getServerUrl()}/uris/${id}/read`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ read }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to mark URI");
  }
  return response.json();
}

export interface MarkAllReadResponse {
  marked_read: number;
}

export async function markAllUrisRead(feedId: number): Promise<MarkAllReadResponse> {
  const response = await fetch(`${getServerUrl()}/feeds/${feedId}/uris/mark-all-read`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to mark all URIs as read");
  }
  return response.json();
}

export async function markAllUrisReadGlobal(): Promise<MarkAllReadResponse> {
  const response = await fetch(`${getServerUrl()}/uris/mark-all-read`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to mark all URIs as read");
  }
  return response.json();
}

export async function markAllUrisReadByConnection(connectionId: number): Promise<MarkAllReadResponse> {
  const response = await fetch(`${getServerUrl()}/connections/${connectionId}/uris/mark-all-read`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to mark all URIs as read");
  }
  return response.json();
}

export async function refreshUriMetadata(id: number): Promise<Uri> {
  const response = await fetch(`${getServerUrl()}/uris/${id}/refresh-metadata`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to refresh URI metadata");
  }
  return response.json();
}

export async function markReadLater(id: number, readLater: boolean): Promise<Uri> {
  const response = await fetch(`${getServerUrl()}/uris/${id}/read-later`, {
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

export async function deleteUri(uri: Uri): Promise<boolean> {
  const confirmed = await confirmAlert({
    title: "Delete URI",
    message: `Are you sure you want to delete "${uri.title || "Untitled"}"?`,
    primaryAction: {
      title: "Delete",
      style: Alert.ActionStyle.Destructive,
    },
  });

  if (confirmed) {
    const response = await fetch(`${getServerUrl()}/uris/${uri.id}`, {
      method: "DELETE",
    });
    if (!response.ok) {
      throw new Error("Failed to delete URI");
    }
    return true;
  }
  return false;
}

export interface CreateUriRequest {
  url: string;
  connection_id?: number;
  kind?: UriKind;
  title?: string;
}

export async function createUri(request: CreateUriRequest): Promise<Uri> {
  const response = await fetch(`${getServerUrl()}/uris`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(request),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to create URI");
  }
  return response.json();
}
