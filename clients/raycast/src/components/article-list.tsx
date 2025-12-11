import { Action, ActionPanel, Icon, Keyboard, List, showToast, Toast } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState } from "react";
import * as ArticleApi from "../api/article";
import { ArticleDetail } from "./article-detail";

interface ArticleListProps {
  feedId: number;
  feedTitle: string;
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "";
  const date = new Date(dateStr);
  return date.toLocaleDateString();
}

export function ArticleList({ feedId, feedTitle }: ArticleListProps) {
  const [showUnreadOnly, setShowUnreadOnly] = useState(false);

  const { isLoading, data, pagination, revalidate } = useFetch(
    (options) => ArticleApi.listUrl({ feedId, page: options.page + 1 }),
    {
      mapResult(result: ArticleApi.ArticlesResponse) {
        return {
          data: result.data,
          hasMore: result.page < result.total_pages,
        };
      },
      keepPreviousData: true,
    },
  );

  const filteredData = showUnreadOnly ? data?.filter((article) => article.read_at === null) : data;

  const toggleRead = async (article: ArticleApi.Article) => {
    const isRead = article.read_at !== null;
    try {
      await ArticleApi.markArticleRead(article.id, !isRead);
      revalidate();
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

  return (
    <List
      isLoading={isLoading}
      pagination={pagination}
      navigationTitle={`${feedTitle} - Articles`}
      searchBarAccessory={
        <List.Dropdown
          tooltip="Filter"
          value={showUnreadOnly ? "unread" : "all"}
          onChange={(value) => setShowUnreadOnly(value === "unread")}
        >
          <List.Dropdown.Item title="All Articles" value="all" />
          <List.Dropdown.Item title="Unread Only" value="unread" />
        </List.Dropdown>
      }
    >
      {filteredData?.map((article) => {
        const isRead = article.read_at !== null;
        return (
          <List.Item
            key={String(article.id)}
            title={article.title || "Untitled"}
            subtitle={article.author || undefined}
            accessories={[
              { text: formatDate(article.published_at) },
              { icon: isRead ? Icon.Checkmark : Icon.Circle, tooltip: isRead ? "Read" : "Unread" },
            ]}
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
                  onAction={() => toggleRead(article)}
                  shortcut={{ modifiers: ["cmd"], key: "m" }}
                />
                <Action.CopyToClipboard
                  title="Copy URL"
                  content={article.url}
                  shortcut={Keyboard.Shortcut.Common.Copy}
                />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
