import { Icon, List } from "@raycast/api";
import { Article } from "../api/article";

function truncateContent(content: string | null, maxLength: number = 1000): string {
  if (!content) return "*No content available*";
  if (content.length <= maxLength) return content;
  return content.substring(0, maxLength) + "...";
}

function buildMarkdown(article: Article): string {
  const imageUrl = article.og_image || article.image_url;
  const imageLine = imageUrl ? `![](${imageUrl})\n\n` : "";
  const content = article.og_description || article.content;
  return imageLine + truncateContent(content);
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "Unknown";
  const date = new Date(dateStr);
  return date.toLocaleDateString();
}

export function ArticleDetailMetadata({ article }: { article: Article }) {
  const isRead = article.read_at !== null;
  const isReadLater = article.read_later_at !== null;
  const by = article.person_name || article.author;
  return (
    <List.Item.Detail
      markdown={buildMarkdown(article)}
      key={article.id}
      metadata={
        <List.Item.Detail.Metadata>
          {by && <List.Item.Detail.Metadata.Label title="By" text={by} />}
          <List.Item.Detail.Metadata.Label title="Published" text={formatDate(article.published_at)} />
          <List.Item.Detail.Metadata.Label
            title="Read"
            text={isRead ? formatDate(article.read_at) : "No"}
            icon={isRead ? Icon.Checkmark : Icon.Circle}
          />
          <List.Item.Detail.Metadata.Label
            title="Read Later"
            text={isReadLater ? formatDate(article.read_later_at) : "No"}
            icon={isReadLater ? Icon.Clock : Icon.Circle}
          />
          {article.tags.length > 0 && (
            <>
              <List.Item.Detail.Metadata.TagList title="Tags">
                {article.tags.map((tag) => (
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
