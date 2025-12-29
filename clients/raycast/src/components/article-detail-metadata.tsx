import { Icon, List } from "@raycast/api";
import { Article } from "../api/article";

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "Unknown";
  const date = new Date(dateStr);
  return date.toLocaleDateString();
}

export function ArticleDetailMetadata({ article }: { article: Article }) {
  const isRead = article.read_at !== null;
  const summary = article.summary || "*No summary available*";
  return (
    <List.Item.Detail
      markdown={summary}
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.Label title="Title" text={article.title || "Untitled"} />
          {article.author && <List.Item.Detail.Metadata.Label title="Author" text={article.author} />}
          <List.Item.Detail.Metadata.Separator />
          <List.Item.Detail.Metadata.Label title="Published" text={formatDate(article.published_at)} />
          <List.Item.Detail.Metadata.Label title="Added" text={formatDate(article.created_at)} />
          <List.Item.Detail.Metadata.Label
            title="Status"
            text={isRead ? `Read on ${formatDate(article.read_at)}` : "Unread"}
            icon={isRead ? Icon.Checkmark : Icon.Circle}
          />
          {article.tags.length > 0 && (
            <>
              <List.Item.Detail.Metadata.Separator />
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
