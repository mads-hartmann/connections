import { Action, ActionPanel, Detail, Icon, showToast, Toast } from "@raycast/api";
import { Article, markArticleRead } from "../api/article";

interface ArticleDetailProps {
  article: Article;
  revalidateArticles: () => void;
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

export function ArticleDetail({ article, revalidateArticles }: ArticleDetailProps) {
  const isRead = article.read_at !== null;

  const toggleRead = async () => {
    try {
      await markArticleRead(article.id, !isRead);
      revalidateArticles();
      showToast({
        style: Toast.Style.Success,
        title: isRead ? "Marked as unread" : "Marked as read",
      });
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update article",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  };

  const metadata = [
    article.author ? `**Author:** ${article.author}` : null,
    `**Published:** ${formatDate(article.published_at)}`,
    isRead ? `**Read:** ${formatDate(article.read_at)}` : "**Status:** Unread",
  ]
    .filter(Boolean)
    .join("\n\n");

  const markdown = `# ${article.title || "Untitled"}

${metadata}

---

${article.content || "*No content available*"}
`;

  return (
    <Detail
      markdown={markdown}
      actions={
        <ActionPanel>
          <Action.OpenInBrowser url={article.url} />
          <Action
            title={isRead ? "Mark as Unread" : "Mark as Read"}
            icon={isRead ? Icon.Circle : Icon.Checkmark}
            onAction={toggleRead}
          />
          <Action.CopyToClipboard title="Copy URL" content={article.url} />
        </ActionPanel>
      }
    />
  );
}
