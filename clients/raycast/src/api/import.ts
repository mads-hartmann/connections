import { getServerUrl } from "./config";

export interface FeedInfo {
  url: string;
  title: string | null;
}

export interface ConnectionInfo {
  name: string;
  feeds: FeedInfo[];
  tags: string[];
}

export interface ImportError {
  url: string;
  error: string;
}

export interface PreviewResponse {
  connections: ConnectionInfo[];
  errors: ImportError[];
}

export interface ConfirmRequest {
  connections: ConnectionInfo[];
}

export interface ConfirmResponse {
  created_connections: number;
  created_feeds: number;
  created_tags: number;
}

export async function previewOpml(opmlContent: string): Promise<PreviewResponse> {
  const response = await fetch(`${getServerUrl()}/import/opml/preview`, {
    method: "POST",
    headers: { "Content-Type": "text/xml" },
    body: opmlContent,
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to parse OPML");
  }
  return response.json();
}

export async function confirmImport(request: ConfirmRequest): Promise<ConfirmResponse> {
  const response = await fetch(`${getServerUrl()}/import/opml/confirm`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(request),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to import");
  }
  return response.json();
}
