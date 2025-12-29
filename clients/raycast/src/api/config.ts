import { getPreferenceValues } from "@raycast/api";

interface Preferences {
  serverUrl: string;
}

export function getServerUrl(): string {
  const { serverUrl } = getPreferenceValues<Preferences>();
  // Remove trailing slash if present
  return serverUrl.replace(/\/$/, "");
}
