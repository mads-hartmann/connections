import { showToast, Toast } from "@raycast/api";
import * as Article from "../api/article";

export async function markAllArticlesRead(revalidate: () => void): Promise<void> {
  try {
    const result = await Article.markAllArticlesReadGlobal();
    await showToast({
      style: Toast.Style.Success,
      title: `Marked ${result.marked_read} articles as read`,
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
