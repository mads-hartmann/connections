import { Alert, confirmAlert } from "@raycast/api";
import { getServerUrl } from "./config";

export interface Feed {
  id: number;
  person_id: number;
  url: string;
  title: string | null;
  created_at: string;
  last_fetched_at: string | null;
}

export interface FeedsResponse {
  data: Feed[];
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export function listUrl({ personId, page }: { personId: number; page: number }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  return `${getServerUrl()}/persons/${personId}/feeds?${params.toString()}`;
}

export function listAllUrl({ page, query }: { page: number; query?: string }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  if (query) {
    params.set("query", query);
  }
  return `${getServerUrl()}/feeds?${params.toString()}`;
}

export async function createFeed(personId: number, url: string, title: string) {
  const response = await fetch(`${getServerUrl()}/persons/${personId}/feeds`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ person_id: personId, url, title }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to create feed");
  }
  return response.json();
}

export async function updateFeed(id: number, url: string, title: string) {
  const response = await fetch(`${getServerUrl()}/feeds/${id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url, title }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to update feed");
  }
  return response.json();
}

export async function deleteFeed(feed: Feed) {
  if (
    await confirmAlert({
      title: "Delete Feed",
      message: `Are you sure you want to delete "${feed.title || feed.url}"?`,
      primaryAction: {
        title: "Delete",
        style: Alert.ActionStyle.Destructive,
      },
    })
  ) {
    await fetch(`${getServerUrl()}/feeds/${feed.id}`, {
      method: "DELETE",
    });
    return true;
  }
  return false;
}

export async function refreshFeed(id: number) {
  const response = await fetch(`${getServerUrl()}/feeds/${id}/refresh`, {
    method: "POST",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to refresh feed");
  }
  return response.json();
}
