import { getServerUrl } from "./config";

export interface Feed {
  url: string;
  title: string | null;
  format: "rss" | "atom" | "json_feed";
}

export interface MetadataFieldType {
  id: number;
  name: string;
}

export interface ClassifiedProfile {
  url: string;
  type: string;
}

export interface ContactMetadataResponse {
  name?: string;
  url?: string;
  email?: string;
  photo?: string;
  bio?: string;
  location?: string;
  feeds: Feed[];
  social_profiles: ClassifiedProfile[];
}

// Map profile type names to field type IDs (matching server enum)
const FIELD_TYPE_MAP: Record<string, MetadataFieldType> = {
  Bluesky: { id: 1, name: "Bluesky" },
  Email: { id: 2, name: "Email" },
  GitHub: { id: 3, name: "GitHub" },
  LinkedIn: { id: 4, name: "LinkedIn" },
  Mastodon: { id: 5, name: "Mastodon" },
  Website: { id: 6, name: "Website" },
  X: { id: 7, name: "X" },
  Other: { id: 8, name: "Other" },
};

export interface ClassifiedProfileWithFieldType {
  url: string;
  field_type: MetadataFieldType;
}

export function classifyProfile(profile: ClassifiedProfile): ClassifiedProfileWithFieldType {
  const fieldType = FIELD_TYPE_MAP[profile.type] || FIELD_TYPE_MAP["Other"];
  return { url: profile.url, field_type: fieldType };
}

export async function fetchContactMetadata(url: string): Promise<ContactMetadataResponse> {
  const params = new URLSearchParams({ url });
  const response = await fetch(`${getServerUrl()}/discovery/connection-metadata?${params.toString()}`);
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to fetch metadata");
  }
  return response.json();
}
