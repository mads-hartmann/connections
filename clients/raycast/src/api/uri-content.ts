import { getServerUrl } from "./config";

export interface UriContent {
  markdown: string;
}

export interface UriContentError {
  error: string;
}

export type UriContentResult = UriContent | UriContentError;

export function isUriContentError(result: UriContentResult): result is UriContentError {
  return "error" in result;
}

export async function fetchUriContent(uriId: number): Promise<UriContentResult> {
  try {
    const response = await fetch(`${getServerUrl()}/uris/${uriId}/content`);

    if (!response.ok) {
      const data = await response.json().catch(() => ({}));
      const errorMessage = data.error || `${response.status} ${response.statusText}`;
      return { error: errorMessage };
    }

    const data = await response.json();
    return { markdown: data.markdown };
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return { error: `Failed to fetch URI content: ${message}` };
  }
}
