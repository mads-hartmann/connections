import { Action, ActionPanel, Icon, Keyboard, List } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import * as Feed from "../api/feed";
import { FeedCreateForm } from "./feed-create-form";
import { FeedListItem } from "./feed-list-item";

interface FeedListProps {
  connectionId: number;
  connectionName: string;
}

export function FeedList({ connectionId, connectionName }: FeedListProps) {
  const { isLoading, data, pagination, revalidate } = useFetch(
    (options) => Feed.listUrl({ connectionId, page: options.page + 1 }),
    {
      mapResult(result: Feed.FeedsResponse) {
        return {
          data: result.data,
          hasMore: result.page < result.total_pages,
        };
      },
      keepPreviousData: true,
    },
  );

  return (
    <List
      isLoading={isLoading}
      pagination={pagination}
      navigationTitle={`${connectionName}'s Feeds`}
      actions={
        <ActionPanel>
          <Action.Push
            title="Create Feed"
            icon={Icon.Plus}
            shortcut={Keyboard.Shortcut.Common.New}
            target={<FeedCreateForm connectionId={connectionId} revalidate={revalidate} />}
          />
        </ActionPanel>
      }
    >
      {data?.map((feed) => (
        <FeedListItem key={String(feed.id)} feed={feed} revalidate={revalidate} connectionId={connectionId} />
      ))}
    </List>
  );
}
