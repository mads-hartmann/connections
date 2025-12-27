import { Action, ActionPanel, Icon, Keyboard, List, showToast, Toast } from "@raycast/api";
import * as Article from "../api/article";
import { ArticleDetail } from "./article-detail";
import { ArticleDetailMetadata } from "./article-detail-metadata";
import { ArticleEditForm } from "./article-edit-form";

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "";
  const date = new Date(dateStr);
  return date.toLocaleDateString();
}

interface ArticleListItemProps {
  article: Article.Article;
  revalidate: () => void;
  showDetail: boolean;
  onToggleDetail: () => void;
  /** If provided, shows Mark All as Read action */
  onMarkAllRead?: () => void;
}

export function ArticleListItem({ article, revalidate, showDetail, onToggleDetail, onMarkAllRead }: ArticleListItemProps) {
  const isRead = article.read_at !== null;

  const toggleRead = async () => {
    try {
      await Article.markArticleRead(article.id, !isRead);
      revalidate();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update article",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  };

  return (
    <List.Item
      key={String(article.id)}
      title={article.title || "Untitled"}
      subtitle={showDetail ? undefined : article.author || undefined}
      accessories={
        showDetail
          ? undefined
          : [
              { text: formatDate(article.published_at) },
              { icon: isRead ? Icon.Checkmark : Icon.Circle, tooltip: isRead ? "Read" : "Unread" },
            ]
      }
      detail={<ArticleDetailMetadata article={article} />}
      actions={
        <ActionPanel>
          <Action.Push
            title="View Article"
            icon={Icon.Eye}
            target={<ArticleDetail article={article} revalidateArticles={revalidate} />}
          />
          <Action.OpenInBrowser url={article.url} shortcut={Keyboard.Shortcut.Common.Open} />
          <Action
            title={isRead ? "Mark as Unread" : "Mark as Read"}
            icon={isRead ? Icon.Circle : Icon.Checkmark}
            onAction={toggleRead}
            shortcut={{ modifiers: ["cmd"], key: "m" }}
          />
          <Action.Push
            title="Edit Article"
            icon={Icon.Pencil}
            shortcut={Keyboard.Shortcut.Common.Edit}
            target={<ArticleEditForm article={article} revalidate={revalidate} />}
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
          <Action.CopyToClipboard title="Copy URL" content={article.url} shortcut={Keyboard.Shortcut.Common.Copy} />
        </ActionPanel>
      }
    />
  );
}
