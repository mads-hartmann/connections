import { Alert, confirmAlert, List, showToast, Toast } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState } from "react";
import * as UriApi from "../api/uri";
import * as Tag from "../api/tag";
import { UriListItem } from "./uri-list-item";

type UriListProps = (
  | { feedId: number; feedTitle: string; tag?: never; connectionId?: never; connectionName?: never }
  | { tag: Tag.Tag; feedId?: never; feedTitle?: never; connectionId?: never; connectionName?: never }
  | { connectionId: number; connectionName: string; feedId?: never; feedTitle?: never; tag?: never }
) & { defaultFilter?: "all" | "unread" };

async function confirmMarkAllRead(feedTitle: string): Promise<boolean> {
  return await confirmAlert({
    title: "Mark All as Read",
    message: `Are you sure you want to mark all URIs in ${feedTitle} as read?`,
    primaryAction: {
      title: "Mark All as Read",
      style: Alert.ActionStyle.Default,
    },
  });
}

export function UriList(props: UriListProps) {
  const [showUnreadOnly, setShowUnreadOnly] = useState(props.defaultFilter === "unread");
  const [showDetail, setShowDetail] = useState(true);

  const isTagView = "tag" in props && props.tag !== undefined;
  const isConnectionView = "connectionId" in props && props.connectionId !== undefined;
  const isFeedView = "feedId" in props && props.feedId !== undefined;

  const navigationTitle = isTagView
    ? `Tag: ${props.tag.name}`
    : isConnectionView
      ? `${props.connectionName} - URIs`
      : `${props.feedTitle} - URIs`;

  const { isLoading, data, pagination, revalidate } = useFetch(
    (options) => {
      if (isTagView) {
        return UriApi.listByTagUrl({ tag: props.tag.name, page: options.page + 1 });
      } else if (isConnectionView) {
        return UriApi.listByConnectionUrl({
          connectionId: props.connectionId,
          page: options.page + 1,
          unread: showUnreadOnly,
        });
      } else {
        return UriApi.listUrl({ feedId: props.feedId, page: options.page + 1 });
      }
    },
    {
      mapResult(result: UriApi.UrisResponse) {
        return {
          data: result.data,
          hasMore: result.page < result.total_pages,
        };
      },
      keepPreviousData: true,
    },
  );

  const filteredData = showUnreadOnly ? data?.filter((uri) => uri.read_at === null) : data;

  const markAllRead = async () => {
    if (isTagView || isConnectionView) return;

    const confirmed = await confirmMarkAllRead(props.feedTitle);
    if (!confirmed) return;

    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Marking all URIs as read",
    });

    try {
      const result = await UriApi.markAllUrisRead(props.feedId);

      toast.style = Toast.Style.Success;
      toast.title = `Marked ${result.marked_read} URI${result.marked_read !== 1 ? "s" : ""} as read`;

      revalidate();
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Failed to mark URIs as read";
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
          <List.Dropdown.Item title="All URIs" value="all" />
          <List.Dropdown.Item title="Unread Only" value="unread" />
        </List.Dropdown>
      }
    >
      {filteredData?.map((uri) => (
        <UriListItem
          key={String(uri.id)}
          uri={uri}
          revalidate={revalidate}
          showDetail={showDetail}
          onToggleDetail={() => setShowDetail(!showDetail)}
          onMarkAllRead={isFeedView ? markAllRead : undefined}
        />
      ))}
    </List>
  );
}
