import { Icon, List } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { Uri } from "../api/uri";
import { fetchUriContent, isUriContentError } from "../api/uri-content";

function truncateContent(content: string, maxLength: number = 1000): string {
  if (content.length <= maxLength) return content;
  return content.substring(0, maxLength) + "...";
}

function buildMarkdown(uri: Uri, serverContent: string | null): string {
  const imageUrl = uri.og_image || uri.image_url;
  const imageLine = imageUrl ? `![](${imageUrl})\n\n` : "";
  const content = serverContent || uri.og_description || uri.content || "*No content available*";
  return imageLine + truncateContent(content);
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "Unknown";
  const date = new Date(dateStr);
  return date.toLocaleDateString();
}

export function UriDetailMetadata({ uri }: { uri: Uri }) {
  const { data: uriContent, isLoading } = usePromise(fetchUriContent, [uri.id]);

  const serverContent =
    uriContent && !isUriContentError(uriContent) ? uriContent.markdown : null;

  const isRead = uri.read_at !== null;
  const isReadLater = uri.read_later_at !== null;
  const by = uri.connection_name || uri.author;
  return (
    <List.Item.Detail
      isLoading={isLoading}
      markdown={buildMarkdown(uri, serverContent)}
      key={uri.id}
      metadata={
        <List.Item.Detail.Metadata>
          {by && <List.Item.Detail.Metadata.Label title="By" text={by} />}
          <List.Item.Detail.Metadata.Label title="Published" text={formatDate(uri.published_at)} />
          <List.Item.Detail.Metadata.Label
            title="Read"
            text={isRead ? formatDate(uri.read_at) : "No"}
            icon={isRead ? Icon.Checkmark : Icon.Circle}
          />
          <List.Item.Detail.Metadata.Label
            title="Read Later"
            text={isReadLater ? formatDate(uri.read_later_at) : "No"}
            icon={isReadLater ? Icon.Clock : Icon.Circle}
          />
          {uri.tags.length > 0 && (
            <>
              <List.Item.Detail.Metadata.TagList title="Tags">
                {uri.tags.map((tag) => (
                  <List.Item.Detail.Metadata.TagList.Item key={tag.id} text={tag.name} />
                ))}
              </List.Item.Detail.Metadata.TagList>
            </>
          )}
        </List.Item.Detail.Metadata>
      }
    />
  );
}
