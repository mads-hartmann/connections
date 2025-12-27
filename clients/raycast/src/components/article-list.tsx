import { Action, ActionPanel, Alert, confirmAlert, Icon, Keyboard, List, showToast, Toast } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState } from "react";
import * as ArticleApi from "../api/article";
import * as Tag from "../api/tag";
import { ArticleDetail } from "./article-detail";
import { ArticleDetailMetadata } from "./article-detail-metadata";

type ArticleListProps =
  | { feedId: number; feedTitle: string; tag?: never }
  | { tag: Tag.Tag; feedId?: never; feedTitle?: never };

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "";
  const date = new Date(dateStr);
  return date.toLocaleDateString();
}

async function confirmMarkAllRead(feedTitle: string): Promise<boolean> {
  return await confirmAlert({
    title: "Mark All as Read",
    message: `Are you sure you want to mark all articles in "${feedTitle}" as read?`,
    primaryAction: {
      title: "Mark All as Read",
      style: Alert.ActionStyle.Default,
    },
  });
}

export function ArticleList(props: ArticleListProps) {
  const [showUnreadOnly, setShowUnreadOnly] = useState(false);
  const [showDetail, setShowDetail] = useState(true);

  const isTagView = "tag" in props && props.tag !== undefined;
  const navigationTitle = isTagView ? `Tag: ${props.tag.name}` : `${props.feedTitle} - Articles`;

  const { isLoading, data, pagination, revalidate } = useFetch(
    (options) =>
      isTagView
        ? ArticleApi.listByTagUrl({ tag: props.tag.name, page: options.page + 1 })
        : ArticleApi.listUrl({ feedId: props.feedId, page: options.page + 1 }),
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
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update article",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  };

  const markAllRead = async () => {
    if (isTagView) return;

    const confirmed = await confirmMarkAllRead(props.feedTitle);
    if (!confirmed) return;

    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Marking all articles as read",
    });

    try {
      const result = await ArticleApi.markAllArticlesRead(props.feedId);

      toast.style = Toast.Style.Success;
      toast.title = `Marked ${result.marked_read} article${result.marked_read !== 1 ? "s" : ""} as read`;

      revalidate();
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Failed to mark articles as read";
      toast.message = error instanceof Error ? error.message : "Unknown error";
    }
  };

  return (
    <List
      isLoading={isLoading}
      pagination={pagination}
      navigationTitle={navigationTitle}
      isShowingDetail={showDetail}
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
                  onAction={() => toggleRead(article)}
                  shortcut={{ modifiers: ["cmd"], key: "m" }}
                />
                <Action
                  title={showDetail ? "Hide Details" : "Show Details"}
                  icon={showDetail ? Icon.EyeDisabled : Icon.Eye}
                  shortcut={{ modifiers: ["cmd"], key: "d" }}
                  onAction={() => setShowDetail(!showDetail)}
                />
                {!isTagView && (
                  <Action
                    title="Mark All as Read"
                    icon={Icon.CheckCircle}
                    onAction={markAllRead}
                    shortcut={{ modifiers: ["cmd", "shift"], key: "m" }}
                  />
                )}
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
