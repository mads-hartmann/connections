import { Action, ActionPanel, Detail, Icon, Keyboard, showToast, Toast } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { Uri, markUriRead, refreshUriMetadata } from "../api/uri";
import { fetchUriContent, isUriContentError } from "../api/uri-content";
import { UriEditForm } from "./uri-edit-form";

interface UriDetailProps {
  uri: Uri;
  revalidateUris: () => void;
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "Unknown date";
  const date = new Date(dateStr);
  return date.toLocaleDateString(undefined, {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

export function UriDetail({ uri, revalidateUris }: UriDetailProps) {
  const isRead = uri.read_at !== null;

  const { data: uriContent, isLoading } = usePromise(fetchUriContent, [uri.id]);

  const toggleRead = async () => {
    try {
      await markUriRead(uri.id, !isRead);
      revalidateUris();
      showToast({
        style: Toast.Style.Success,
        title: isRead ? "Marked as unread" : "Marked as read",
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
      await refreshUriMetadata(uri.id);
      revalidateUris();
      toast.style = Toast.Style.Success;
      toast.title = "Metadata refreshed";
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Failed to refresh metadata";
      toast.message = error instanceof Error ? error.message : "Unknown error";
    }
  };

  const imageUrl = uri.og_image || uri.image_url;
  const imageLine = imageUrl ? `![](${imageUrl})\n\n` : "";

  let contentBody: string;
  if (uriContent && isUriContentError(uriContent)) {
    contentBody = `⚠️ ${uriContent.error}\n\n---\n\n${uri.og_description || uri.content || "*No content available*"}`;
  } else if (uriContent) {
    contentBody = uriContent.markdown;
  } else {
    contentBody = uri.og_description || uri.content || "*No content available*";
  }

  const markdown = `# ${uri.title || "Untitled"}
${imageLine}
${contentBody}
`;

  return (
    <Detail
      isLoading={isLoading}
      markdown={markdown}
      metadata={
        <Detail.Metadata>
          {uri.tags && (
            <Detail.Metadata.TagList title="Tags">
              {uri.tags.map((tag) => (
                <Detail.Metadata.TagList.Item key={tag.id} text={tag.name} />
              ))}
            </Detail.Metadata.TagList>
          )}
          <Detail.Metadata.Separator />
          {uri.author && <Detail.Metadata.Label title="Author" text={uri.author} />}
          <Detail.Metadata.Label title="Published" text={formatDate(uri.published_at)} />
          <Detail.Metadata.Label title="Read" text={isRead ? formatDate(uri.read_at) : "Unread"} />
        </Detail.Metadata>
      }
      navigationTitle={uri.title || undefined}
      actions={
        <ActionPanel>
          <Action.OpenInBrowser url={uri.url} />
          <Action
            title={isRead ? "Mark as Unread" : "Mark as Read"}
            icon={isRead ? Icon.Circle : Icon.Checkmark}
            onAction={toggleRead}
          />
          <Action.Push
            title="Edit URI"
            icon={Icon.Pencil}
            shortcut={Keyboard.Shortcut.Common.Edit}
            target={<UriEditForm uri={uri} revalidate={revalidateUris} />}
          />
          <Action
            title="Refresh Metadata"
            icon={Icon.ArrowClockwise}
            shortcut={{ modifiers: ["cmd"], key: "r" }}
            onAction={refreshMetadata}
          />
          <Action.CopyToClipboard title="Copy URL" content={uri.url} />
        </ActionPanel>
      }
    />
  );
}
