import { Alert, confirmAlert, List, showToast, Toast } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState } from "react";
import * as ArticleApi from "../api/article";
import * as Tag from "../api/tag";
import { ArticleListItem } from "./article-list-item";

type ArticleListProps = (
  | { feedId: number; feedTitle: string; tag?: never; personId?: never; personName?: never }
  | { tag: Tag.Tag; feedId?: never; feedTitle?: never; personId?: never; personName?: never }
  | { personId: number; personName: string; feedId?: never; feedTitle?: never; tag?: never }
) & { defaultFilter?: "all" | "unread" };

async function confirmMarkAllRead(feedTitle: string): Promise<boolean> {
  return await confirmAlert({
    title: "Mark All as Read",
    message: `Are you sure you want to mark all articles in ${feedTitle} as read?`,
    primaryAction: {
      title: "Mark All as Read",
      style: Alert.ActionStyle.Default,
    },
  });
}

export function ArticleList(props: ArticleListProps) {
  const [showUnreadOnly, setShowUnreadOnly] = useState(props.defaultFilter === "unread");
  const [showDetail, setShowDetail] = useState(true);

  const isTagView = "tag" in props && props.tag !== undefined;
  const isPersonView = "personId" in props && props.personId !== undefined;
  const isFeedView = "feedId" in props && props.feedId !== undefined;

  const navigationTitle = isTagView
    ? `Tag: ${props.tag.name}`
    : isPersonView
      ? `${props.personName} - Articles`
      : `${props.feedTitle} - Articles`;

  const { isLoading, data, pagination, revalidate } = useFetch(
    (options) => {
      if (isTagView) {
        return ArticleApi.listByTagUrl({ tag: props.tag.name, page: options.page + 1 });
      } else if (isPersonView) {
        return ArticleApi.listByPersonUrl({ personId: props.personId, page: options.page + 1 });
      } else {
        return ArticleApi.listUrl({ feedId: props.feedId, page: options.page + 1 });
      }
    },
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

  const markAllRead = async () => {
    if (isTagView || isPersonView) return;

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
      {filteredData?.map((article) => (
        <ArticleListItem
          key={String(article.id)}
          article={article}
          revalidate={revalidate}
          showDetail={showDetail}
          onToggleDetail={() => setShowDetail(!showDetail)}
          onMarkAllRead={isFeedView ? markAllRead : undefined}
        />
      ))}
    </List>
  );
}
