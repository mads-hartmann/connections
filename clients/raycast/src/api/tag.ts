import { Alert, confirmAlert } from "@raycast/api";
import { getServerUrl } from "./config";

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
  return `${getServerUrl()}/tags?${params.toString()}`;
}

export async function listAll(): Promise<Tag[]> {
  const allTags: Tag[] = [];
  let page = 1;
  let hasMore = true;

  while (hasMore) {
    const response = await fetch(`${getServerUrl()}/tags?page=${page}&per_page=100`);
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || "Failed to fetch tags");
    }
    const data: TagsResponse = await response.json();
    allTags.push(...data.data);
    hasMore = page < data.total_pages;
    page++;
  }

  return allTags;
}

export function listByConnectionUrl(connectionId: number) {
  return `${getServerUrl()}/connections/${connectionId}/tags`;
}

export function listByFeedUrl(feedId: number) {
  return `${getServerUrl()}/feeds/${feedId}/tags`;
}

export async function getTag(id: number): Promise<Tag> {
  const response = await fetch(`${getServerUrl()}/tags/${id}`);
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to fetch tag");
  }
  return response.json();
}

export async function createTag(name: string): Promise<Tag> {
  const response = await fetch(`${getServerUrl()}/tags`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to create tag");
  }
  return response.json();
}

export async function updateTag(id: number, name: string): Promise<Tag> {
  const response = await fetch(`${getServerUrl()}/tags/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to update tag");
  }
  return response.json();
}

export async function deleteTag(tag: Tag): Promise<boolean> {
  if (
    await confirmAlert({
      title: "Delete Tag",
      message: `Are you sure you want to delete "${tag.name}"?`,
      primaryAction: {
        title: "Delete",
        style: Alert.ActionStyle.Destructive,
      },
    })
  ) {
    const response = await fetch(`${getServerUrl()}/tags/${tag.id}`, {
      method: "DELETE",
    });
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || "Failed to delete tag");
    }
    return true;
  }
  return false;
}

// Connection-Tag associations

export async function listByConnection(connectionId: number): Promise<Tag[]> {
  const response = await fetch(`${getServerUrl()}/connections/${connectionId}/tags`);
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to fetch connection tags");
  }
  return response.json();
}

export async function addToConnection(connectionId: number, tagId: number): Promise<void> {
  const response = await fetch(`${getServerUrl()}/connections/${connectionId}/tags/${tagId}`, {
    method: "POST",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to add tag to connection");
  }
}

export async function removeFromConnection(connectionId: number, tagId: number): Promise<void> {
  const response = await fetch(`${getServerUrl()}/connections/${connectionId}/tags/${tagId}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to remove tag from connection");
  }
}

// Feed-Tag associations

export async function listByFeed(feedId: number): Promise<Tag[]> {
  const response = await fetch(`${getServerUrl()}/feeds/${feedId}/tags`);
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to fetch feed tags");
  }
  return response.json();
}

export async function addToFeed(feedId: number, tagId: number): Promise<void> {
  const response = await fetch(`${getServerUrl()}/feeds/${feedId}/tags/${tagId}`, {
    method: "POST",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to add tag to feed");
  }
}

export async function removeFromFeed(feedId: number, tagId: number): Promise<void> {
  const response = await fetch(`${getServerUrl()}/feeds/${feedId}/tags/${tagId}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to remove tag from feed");
  }
}

// URI-Tag associations

export async function addToUri(uriId: number, tagId: number): Promise<void> {
  const response = await fetch(`${getServerUrl()}/uris/${uriId}/tags/${tagId}`, {
    method: "POST",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to add tag to URI");
  }
}

export async function removeFromUri(uriId: number, tagId: number): Promise<void> {
  const response = await fetch(`${getServerUrl()}/uris/${uriId}/tags/${tagId}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to remove tag from URI");
  }
}
