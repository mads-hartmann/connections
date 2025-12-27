import { Action, ActionPanel, Icon, Keyboard, List, showToast, Toast } from "@raycast/api";
import * as Feed from "../api/feed";
import { ArticleList } from "./article-list";
import { FeedCreateForm } from "./feed-create-form";
import { FeedEditForm } from "./feed-edit-form";

function formatLastFetched(lastFetchedAt: string | null): string {
  if (!lastFetchedAt) {
    return "Never fetched";
  }
  const date = new Date(lastFetchedAt);
  return `Fetched ${date.toLocaleDateString()}`;
}

interface FeedListItemProps {
  feed: Feed.Feed;
  revalidate: () => void;
  /** If provided, shows Create Feed action */
  personId?: number;
}

export function FeedListItem({ feed, revalidate, personId }: FeedListItemProps) {
  const deleteFeed = async () => {
    const deleted = await Feed.deleteFeed(feed);
    if (deleted) {
      revalidate();
    }
  };

  const refreshFeed = async () => {
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
    <List.Item
      key={String(feed.id)}
      title={feed.title || feed.url}
      subtitle={feed.title ? feed.url : undefined}
      accessories={[{ text: formatLastFetched(feed.last_fetched_at), tooltip: "Last fetched" }]}
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
            target={<FeedEditForm feed={feed} revalidate={revalidate} />}
          />
          {personId !== undefined && (
            <Action.Push
              title="Create Feed"
              icon={Icon.Plus}
              shortcut={Keyboard.Shortcut.Common.New}
              target={<FeedCreateForm personId={personId} revalidate={revalidate} />}
            />
          )}
          <Action
            title="Refresh Feed"
            icon={Icon.ArrowClockwise}
            shortcut={Keyboard.Shortcut.Common.Refresh}
            onAction={refreshFeed}
          />
          <Action
            title="Delete"
            icon={Icon.Trash}
            style={Action.Style.Destructive}
            onAction={deleteFeed}
            shortcut={Keyboard.Shortcut.Common.Remove}
          />
        </ActionPanel>
      }
    />
  );
}
