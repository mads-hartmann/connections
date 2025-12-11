import { Action, ActionPanel, Icon, Keyboard, List } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import * as Feed from "../api/feed";
import { CreateFeedForm } from "./create-feed-form";
import { EditFeedForm } from "./edit-feed-form";

interface FeedListProps {
  personId: number;
  personName: string;
}

function formatLastFetched(lastFetchedAt: string | null): string {
  if (!lastFetchedAt) {
    return "Never fetched";
  }
  const date = new Date(lastFetchedAt);
  return `Fetched ${date.toLocaleDateString()}`;
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

  const deleteFeed = async (feed: Feed.Feed) => {
    const deleted = await Feed.deleteFeed(feed);
    if (deleted) {
      revalidate();
    }
  };

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
        <List.Item
          key={String(feed.id)}
          title={feed.title || feed.url}
          subtitle={feed.title ? feed.url : undefined}
          accessories={[{ text: formatLastFetched(feed.last_fetched_at) }]}
          actions={
            <ActionPanel>
              <Action.Push
                title="Edit Feed"
                icon={Icon.Pencil}
                target={<EditFeedForm feed={feed} revalidate={revalidate} />}
              />
              <Action.Push
                title="Create Feed"
                icon={Icon.Plus}
                shortcut={Keyboard.Shortcut.Common.New}
                target={<CreateFeedForm personId={personId} revalidate={revalidate} />}
              />
              <Action
                title="Delete"
                icon={Icon.Trash}
                style={Action.Style.Destructive}
                onAction={() => deleteFeed(feed)}
                shortcut={Keyboard.Shortcut.Common.Remove}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
