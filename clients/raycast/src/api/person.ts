import { Alert, confirmAlert } from "@raycast/api";
import { Tag } from "./tag";
import { getServerUrl } from "./config";

export interface MetadataFieldType {
  id: number;
  name: string;
}

export interface PersonMetadata {
  id: number;
  field_type: MetadataFieldType;
  value: string;
}

export interface Person {
  id: number;
  name: string;
  photo?: string;
  feed_count: number;
  article_count: number;
  unread_article_count: number;
  metadata: PersonMetadata[];
  tags: Tag[];
}

export interface PersonDetail {
  id: number;
  name: string;
  photo?: string;
  metadata: PersonMetadata[];
}

export interface PersonsResponse {
  data: Person[];
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

// Known field types matching server enum
export const FIELD_TYPES: MetadataFieldType[] = [
  { id: 1, name: "Bluesky" },
  { id: 2, name: "Email" },
  { id: 3, name: "GitHub" },
  { id: 4, name: "LinkedIn" },
  { id: 5, name: "Mastodon" },
  { id: 6, name: "Website" },
  { id: 7, name: "X" },
  { id: 8, name: "Other" },
];

export function listUrl({ page, query }: { page: number; query?: string }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  if (query) {
    params.append("query", query);
  }
  return `${getServerUrl()}/persons?${params.toString()}`;
}

export async function getPerson(id: number): Promise<PersonDetail> {
  const response = await fetch(`${getServerUrl()}/persons/${id}`);
  if (!response.ok) {
    throw new Error("Failed to fetch person");
  }
  return response.json();
}

export async function updatePerson(id: number, name: string, photo?: string | null): Promise<PersonDetail> {
  const body: { name: string; photo?: string | null } = { name };
  if (photo !== undefined) {
    body.photo = photo;
  }
  const response = await fetch(`${getServerUrl()}/persons/${id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to update person");
  }
  return response.json();
}

export async function deletePerson(person: Person) {
  if (
    await confirmAlert({
      title: "Delete Person",
      message: `Are you sure you want to delete "${person.name}"?`,
      primaryAction: {
        title: "Delete",
        style: Alert.ActionStyle.Destructive,
      },
    })
  ) {
    await fetch(`${getServerUrl()}/persons/${person.id}`, {
      method: "DELETE",
    });
  }
}

export async function createMetadata(personId: number, fieldTypeId: number, value: string): Promise<PersonMetadata> {
  const response = await fetch(`${getServerUrl()}/persons/${personId}/metadata`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ field_type_id: fieldTypeId, value }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to create metadata");
  }
  return response.json();
}

export async function updateMetadata(personId: number, metadataId: number, value: string): Promise<PersonMetadata> {
  const response = await fetch(`${getServerUrl()}/persons/${personId}/metadata/${metadataId}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ value }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to update metadata");
  }
  return response.json();
}

export async function deleteMetadata(personId: number, metadataId: number): Promise<void> {
  const response = await fetch(`${getServerUrl()}/persons/${personId}/metadata/${metadataId}`, {
    method: "DELETE",
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to delete metadata");
  }
}

// Refresh metadata types
export interface RefreshMetadataFeed {
  url: string;
  title?: string;
  format: "rss" | "atom" | "json_feed";
}

export interface RefreshMetadataProfile {
  url: string;
  field_type: MetadataFieldType;
}

export interface RefreshMetadataPreview {
  person_id: number;
  source_url: string;
  proposed_name?: string;
  proposed_photo?: string;
  proposed_feeds: RefreshMetadataFeed[];
  proposed_profiles: RefreshMetadataProfile[];
  current_name: string;
  current_photo?: string;
  current_metadata: PersonMetadata[];
}

export async function fetchRefreshMetadataPreview(personId: number): Promise<RefreshMetadataPreview> {
  const response = await fetch(`${getServerUrl()}/persons/${personId}/refresh-metadata`);
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to fetch refresh metadata preview");
  }
  return response.json();
}
