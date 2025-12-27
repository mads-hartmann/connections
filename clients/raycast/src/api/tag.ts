import { Alert, confirmAlert } from "@raycast/api";

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

const BASE_URL = "http://localhost:8080";

export function listUrl({ page, query }: { page: number; query?: string }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  if (query) {
    params.set("query", query);
  }
  return `${BASE_URL}/tags?${params.toString()}`;
}

export async function listAll(): Promise<Tag[]> {
  const allTags: Tag[] = [];
  let page = 1;
  let hasMore = true;

  while (hasMore) {
    const response = await fetch(`${BASE_URL}/tags?page=${page}&per_page=100`);
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

export async function getTag(id: number): Promise<Tag> {
  const response = await fetch(`${BASE_URL}/tags/${id}`);
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to fetch tag");
  }
  return response.json();
}

export async function createTag(name: string): Promise<Tag> {
  const response = await fetch(`${BASE_URL}/tags`, {
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
  const response = await fetch(`${BASE_URL}/tags/${id}`, {
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
    const response = await fetch(`${BASE_URL}/tags/${tag.id}`, {
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

// Person-Tag associations

export async function listByPerson(personId: number): Promise<Tag[]> {
  const response = await fetch(`${BASE_URL}/persons/${personId}/tags`);
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to fetch person tags");
  }
  return response.json();
}

export async function addToPerson(personId: number, tagId: number): Promise<void> {
  const response = await fetch(`${BASE_URL}/persons/${personId}/tags/${tagId}`, {
    method: "POST",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to add tag to person");
  }
}

export async function removeFromPerson(personId: number, tagId: number): Promise<void> {
  const response = await fetch(`${BASE_URL}/persons/${personId}/tags/${tagId}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to remove tag from person");
  }
}

// Feed-Tag associations

export async function listByFeed(feedId: number): Promise<Tag[]> {
  const response = await fetch(`${BASE_URL}/feeds/${feedId}/tags`);
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to fetch feed tags");
  }
  return response.json();
}

export async function addToFeed(feedId: number, tagId: number): Promise<void> {
  const response = await fetch(`${BASE_URL}/feeds/${feedId}/tags/${tagId}`, {
    method: "POST",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to add tag to feed");
  }
}

export async function removeFromFeed(feedId: number, tagId: number): Promise<void> {
  const response = await fetch(`${BASE_URL}/feeds/${feedId}/tags/${tagId}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to remove tag from feed");
  }
}

// Article-Tag associations

export async function addToArticle(articleId: number, tagId: number): Promise<void> {
  const response = await fetch(`${BASE_URL}/articles/${articleId}/tags/${tagId}`, {
    method: "POST",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to add tag to article");
  }
}

export async function removeFromArticle(articleId: number, tagId: number): Promise<void> {
  const response = await fetch(`${BASE_URL}/articles/${articleId}/tags/${tagId}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to remove tag from article");
  }
}
