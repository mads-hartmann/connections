import { Action, ActionPanel, Icon, Keyboard, List, showToast, Toast } from "@raycast/api";
import * as Uri from "../api/uri";
import { UriDetail } from "./uri-detail";
import { UriDetailMetadata } from "./uri-detail-metadata";
import { UriEditForm } from "./uri-edit-form";

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "";
  const date = new Date(dateStr);
  return date.toLocaleDateString();
}

interface UriListItemProps {
  uri: Uri.Uri;
  revalidate: () => void;
  showDetail: boolean;
  onToggleDetail: () => void;
  /** If provided, shows Mark All as Read action */
  onMarkAllRead?: () => void;
}

export function UriListItem({ uri, revalidate, showDetail, onToggleDetail, onMarkAllRead }: UriListItemProps) {
  const isRead = uri.read_at !== null;
  const isReadLater = uri.read_later_at !== null;

  const toggleRead = async () => {
    try {
      await Uri.markUriRead(uri.id, !isRead);
      revalidate();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update URI",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  };

  const toggleReadLater = async () => {
    try {
      await Uri.markReadLater(uri.id, !isReadLater);
      revalidate();
      await showToast({
        style: Toast.Style.Success,
        title: isReadLater ? "Removed from Read Later" : "Added to Read Later",
      });
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update URI",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  };

  const refreshMetadata = async () => {
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Fetching metadata...",
    });
    try {
      await Uri.refreshUriMetadata(uri.id);
      revalidate();
      toast.style = Toast.Style.Success;
      toast.title = "Metadata refreshed";
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Failed to refresh metadata";
      toast.message = error instanceof Error ? error.message : "Unknown error";
    }
  };

  const deleteUri = async () => {
    try {
      const deleted = await Uri.deleteUri(uri);
      if (deleted) {
        revalidate();
      }
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to delete URI",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  };

  const subtitle = showDetail ? undefined : uri.connection_name || uri.author || undefined;

  return (
    <List.Item
      key={String(uri.id)}
      title={uri.title || "Untitled"}
      subtitle={subtitle}
      accessories={
        showDetail
          ? undefined
          : [
              { text: formatDate(uri.published_at) },
              { icon: isRead ? Icon.Checkmark : Icon.Circle, tooltip: isRead ? "Read" : "Unread" },
            ]
      }
      detail={<UriDetailMetadata uri={uri} />}
      actions={
        <ActionPanel>
          <Action.Push title="View URI" icon={Icon.Eye} target={<UriDetail uri={uri} revalidateUris={revalidate} />} />
          <Action.OpenInBrowser url={uri.url} shortcut={Keyboard.Shortcut.Common.Open} />
          <Action
            title={isRead ? "Mark as Unread" : "Mark as Read"}
            icon={isRead ? Icon.Circle : Icon.Checkmark}
            onAction={toggleRead}
            shortcut={{ modifiers: ["cmd"], key: "m" }}
          />
          <Action
            title={isReadLater ? "Remove from Read Later" : "Read Later"}
            icon={isReadLater ? Icon.XMarkCircle : Icon.Clock}
            onAction={toggleReadLater}
            shortcut={{ modifiers: ["cmd"], key: "l" }}
          />
          <Action.Push
            title="Edit URI"
            icon={Icon.Pencil}
            shortcut={Keyboard.Shortcut.Common.Edit}
            target={<UriEditForm uri={uri} revalidate={revalidate} />}
          />
          <Action
            title="Delete"
            icon={Icon.Trash}
            style={Action.Style.Destructive}
            shortcut={Keyboard.Shortcut.Common.Remove}
            onAction={deleteUri}
          />
          <Action
            title={showDetail ? "Hide Details" : "Show Details"}
            icon={showDetail ? Icon.EyeDisabled : Icon.Eye}
            shortcut={{ modifiers: ["cmd"], key: "d" }}
            onAction={onToggleDetail}
          />
          {onMarkAllRead && (
            <Action
              title="Mark All as Read"
              icon={Icon.CheckCircle}
              onAction={onMarkAllRead}
              shortcut={{ modifiers: ["cmd", "shift"], key: "m" }}
            />
          )}
          <Action
            title="Refresh Metadata"
            icon={Icon.ArrowClockwise}
            shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
            onAction={refreshMetadata}
          />
          <Action.CopyToClipboard title="Copy URL" content={uri.url} shortcut={Keyboard.Shortcut.Common.Copy} />
        </ActionPanel>
      }
    />
  );
}
