import { showToast, Toast } from "@raycast/api";
import * as Uri from "../api/uri";

export async function markAllUrisRead(revalidate: () => void): Promise<void> {
  try {
    const result = await Uri.markAllUrisReadGlobal();
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
