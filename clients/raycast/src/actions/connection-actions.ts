import { Alert, confirmAlert, showToast, Toast } from "@raycast/api";
import * as Uri from "../api/uri";

export async function markAllUrisReadByConnection(
  connectionId: number,
  connectionName: string,
  revalidate: () => void,
): Promise<void> {
  const confirmed = await confirmAlert({
    title: "Mark All as Read",
    message: `Mark all URIs from ${connectionName} as read?`,
    primaryAction: {
      title: "Mark All as Read",
      style: Alert.ActionStyle.Default,
    },
  });

  if (!confirmed) {
    return;
  }

  try {
    const result = await Uri.markAllUrisReadByConnection(connectionId);
    await showToast({
      style: Toast.Style.Success,
      title: `Marked ${result.marked_read} URIs as read`,
    });
    revalidate();
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Failed to mark all as read",
      message: error instanceof Error ? error.message : "Unknown error",
    });
  }
}
