import { Action, ActionPanel, Icon, Keyboard, List } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import * as Feed from "../api/feed";
import { CreateFeedForm } from "./create-feed-form";
import { FeedItem } from "./feed-item";

interface FeedListProps {
  personId: number;
  personName: string;
}

export function FeedList({ personId, personName }: FeedListProps) {
  const { isLoading, data, pagination, revalidate } = useFetch(
    (options) => Feed.listUrl({ personId, page: options.page + 1 }),
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
      navigationTitle={`${personName}'s Feeds`}
      actions={
        <ActionPanel>
          <Action.Push
            title="Create Feed"
            icon={Icon.Plus}
            shortcut={Keyboard.Shortcut.Common.New}
            target={<CreateFeedForm personId={personId} revalidate={revalidate} />}
          />
        </ActionPanel>
      }
    >
      {data?.map((feed) => (
        <FeedItem key={String(feed.id)} feed={feed} revalidate={revalidate} personId={personId} />
      ))}
    </List>
  );
}
