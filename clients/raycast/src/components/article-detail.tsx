import { Action, ActionPanel, Detail, Icon, Keyboard, showToast, Toast } from "@raycast/api";
import { Article, markArticleRead, refreshArticleMetadata } from "../api/article";
import { ArticleEditForm } from "./article-edit-form";

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

  const refreshMetadata = async () => {
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Fetching metadata...",
    });
    try {
      await refreshArticleMetadata(article.id);
      revalidateArticles();
      toast.style = Toast.Style.Success;
      toast.title = "Metadata refreshed";
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Failed to refresh metadata";
      toast.message = error instanceof Error ? error.message : "Unknown error";
    }
  };

  const tagsLine = article.tags.length > 0 ? `**Tags:** ${article.tags.map((t) => t.name).join(", ")}` : null;

  const metadata = [
    article.author ? `**Author:** ${article.author}` : null,
    `**Published:** ${formatDate(article.published_at)}`,
    isRead ? `**Read:** ${formatDate(article.read_at)}` : "**Status:** Unread",
    tagsLine,
  ]
    .filter(Boolean)
    .join("\n\n");

  const imageUrl = article.og_image || article.image_url;
  const imageLine = imageUrl ? `![](${imageUrl})\n\n` : "";

  const markdown = `# ${article.title || "Untitled"}

${imageLine}${metadata}

---

${article.og_description || article.content || "*No content available*"}
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
          <Action.Push
            title="Edit Article"
            icon={Icon.Pencil}
            shortcut={Keyboard.Shortcut.Common.Edit}
            target={<ArticleEditForm article={article} revalidate={revalidateArticles} />}
          />
          <Action
            title="Refresh Metadata"
            icon={Icon.ArrowClockwise}
            shortcut={{ modifiers: ["cmd"], key: "r" }}
            onAction={refreshMetadata}
          />
          <Action.CopyToClipboard title="Copy URL" content={article.url} />
        </ActionPanel>
      }
    />
  );
}
