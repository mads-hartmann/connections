import { Alert, confirmAlert, showToast, Toast } from "@raycast/api";
import * as Article from "../api/article";

export async function markAllArticlesReadByPerson(
  personId: number,
  personName: string,
  revalidate: () => void,
): Promise<void> {
  const confirmed = await confirmAlert({
    title: "Mark All as Read",
    message: `Mark all articles from ${personName} as read?`,
    primaryAction: {
      title: "Mark All as Read",
      style: Alert.ActionStyle.Default,
    },
  });

  if (!confirmed) {
    return;
  }

  try {
    const result = await Article.markAllArticlesReadByPerson(personId);
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
