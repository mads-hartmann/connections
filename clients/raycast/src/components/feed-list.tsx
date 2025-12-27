import { Action, ActionPanel, Icon, Keyboard, List, showToast, Toast } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import * as Feed from "../api/feed";
import { ArticleList } from "./article-list";
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

  const refreshFeed = async (feed: Feed.Feed) => {
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Refreshing feed",
    });
    try {
      await Feed.refreshFeed(feed.id);
      toast.style = Toast.Style.Success;
      toast.title = "Feed refreshed";
      revalidate();
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Failed to refresh feed";
      toast.message = error instanceof Error ? error.message : "Unknown error";
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
                title="View Articles"
                icon={Icon.List}
                target={<ArticleList feedId={feed.id} feedTitle={feed.title || feed.url} />}
              />
              <Action.Push
                title="Edit Feed"
                icon={Icon.Pencil}
                shortcut={Keyboard.Shortcut.Common.Edit}
                target={<EditFeedForm feed={feed} revalidate={revalidate} />}
              />
              <Action.Push
                title="Create Feed"
                icon={Icon.Plus}
                shortcut={Keyboard.Shortcut.Common.New}
                target={<CreateFeedForm personId={personId} revalidate={revalidate} />}
              />
              <Action
                title="Refresh Feed"
                icon={Icon.ArrowClockwise}
                shortcut={Keyboard.Shortcut.Common.Refresh}
                onAction={() => refreshFeed(feed)}
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
