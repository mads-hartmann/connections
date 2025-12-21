import { Action, ActionPanel, Icon, Keyboard, List, showToast, Toast } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState } from "react";
import { CreatePersonForm } from "./components/create-person-form";
import { FeedList } from "./components/feed-list";
import { ImportOpml } from "./components/import-opml";
import { ArticleList } from "./components/article-list";
import { ArticleDetail } from "./components/article-detail";
import * as Person from "./api/person";
import * as Feed from "./api/feed";
import * as Article from "./api/article";

type ViewType = "connections" | "feeds" | "articles";

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "";
  const date = new Date(dateStr);
  return date.toLocaleDateString();
}

export default function Command() {
  const [selectedView, setSelectedView] = useState<ViewType>("connections");
  const [searchText, setSearchText] = useState("");

  // Fetch connections (people)
  const {
    isLoading: isLoadingConnections,
    data: connectionsData,
    pagination: connectionsPagination,
    revalidate: revalidateConnections,
  } = useFetch((options) => Person.listUrl({ page: options.page + 1, query: searchText || undefined }), {
    mapResult(result: Person.PersonsResponse) {
      return {
        data: result.data,
        hasMore: result.page < result.total_pages,
      };
    },
    keepPreviousData: true,
    execute: selectedView === "connections",
  });

  // Fetch all feeds
  const {
    isLoading: isLoadingFeeds,
    data: feedsData,
    pagination: feedsPagination,
    revalidate: revalidateFeeds,
  } = useFetch((options) => Feed.listAllUrl({ page: options.page + 1 }), {
    mapResult(result: Feed.FeedsResponse) {
      return {
        data: result.data,
        hasMore: result.page < result.total_pages,
      };
    },
    keepPreviousData: true,
    execute: selectedView === "feeds",
  });

  // Fetch all articles
  const {
    isLoading: isLoadingArticles,
    data: articlesData,
    pagination: articlesPagination,
    revalidate: revalidateArticles,
  } = useFetch((options) => Article.listAllUrl({ page: options.page + 1 }), {
    mapResult(result: Article.ArticlesResponse) {
      return {
        data: result.data,
        hasMore: result.page < result.total_pages,
      };
    },
    keepPreviousData: true,
    execute: selectedView === "articles",
  });

  const deletePerson = async (person: Person.Person) => {
    await Person.deletePerson(person);
    revalidateConnections();
  };

  const deleteFeed = async (feed: Feed.Feed) => {
    const deleted = await Feed.deleteFeed(feed);
    if (deleted) {
      revalidateFeeds();
    }
  };

  const refreshFeed = async (feed: Feed.Feed) => {
    try {
      await Feed.refreshFeed(feed.id);
      showToast({ style: Toast.Style.Success, title: "Feed refreshed" });
      revalidateFeeds();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to refresh feed",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  };

  const toggleArticleRead = async (article: Article.Article) => {
    const isRead = article.read_at !== null;
    try {
      await Article.markArticleRead(article.id, !isRead);
      revalidateArticles();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update article",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  };

  // Determine current loading state and pagination based on selected view
  const isLoading =
    selectedView === "connections"
      ? isLoadingConnections
      : selectedView === "feeds"
        ? isLoadingFeeds
        : isLoadingArticles;

  const pagination =
    selectedView === "connections"
      ? connectionsPagination
      : selectedView === "feeds"
        ? feedsPagination
        : articlesPagination;

  const searchBarPlaceholder =
    selectedView === "connections"
      ? "Search people..."
      : selectedView === "feeds"
        ? "Search feeds..."
        : "Search articles...";

  return (
    <List
      isLoading={isLoading}
      pagination={pagination}
      filtering={false}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder={searchBarPlaceholder}
      searchBarAccessory={
        <List.Dropdown
          tooltip="Select View"
          value={selectedView}
          onChange={(value) => setSelectedView(value as ViewType)}
        >
          <List.Dropdown.Item title="Connections" value="connections" />
          <List.Dropdown.Item title="Feeds" value="feeds" />
          <List.Dropdown.Item title="Articles" value="articles" />
        </List.Dropdown>
      }
      actions={
        selectedView === "connections" ? (
          <ActionPanel>
            <Action.Push
              title="Create Person"
              icon={Icon.Plus}
              shortcut={Keyboard.Shortcut.Common.New}
              target={<CreatePersonForm revalidate={revalidateConnections} />}
            />
            <Action.Push
              title="Import from OPML"
              icon={Icon.Download}
              shortcut={{ modifiers: ["cmd", "shift"], key: "i" }}
              target={<ImportOpml revalidate={revalidateConnections} />}
            />
          </ActionPanel>
        ) : undefined
      }
    >
      {selectedView === "connections" &&
        connectionsData?.map((person) => (
          <List.Item
            key={String(person.id)}
            title={person.name}
            accessories={[{ text: `${person.feed_count} feeds` }, { text: `${person.article_count} articles` }]}
            actions={
              <ActionPanel>
                <Action.Push
                  title="View Feeds"
                  icon={Icon.List}
                  target={<FeedList personId={person.id} personName={person.name} />}
                />
                <Action.Push
                  title="Create Person"
                  icon={Icon.Plus}
                  shortcut={Keyboard.Shortcut.Common.New}
                  target={<CreatePersonForm revalidate={revalidateConnections} />}
                />
                <Action.Push
                  title="Import from OPML"
                  icon={Icon.Download}
                  shortcut={{ modifiers: ["cmd", "shift"], key: "i" }}
                  target={<ImportOpml revalidate={revalidateConnections} />}
                />
                <Action
                  title="Delete"
                  icon={Icon.Trash}
                  style={Action.Style.Destructive}
                  onAction={() => deletePerson(person)}
                  shortcut={Keyboard.Shortcut.Common.Remove}
                />
              </ActionPanel>
            }
          />
        ))}

      {selectedView === "feeds" &&
        feedsData?.map((feed) => (
          <List.Item
            key={String(feed.id)}
            title={feed.title || feed.url}
            subtitle={feed.title ? feed.url : undefined}
            accessories={[{ text: formatDate(feed.last_fetched_at), tooltip: "Last fetched" }]}
            actions={
              <ActionPanel>
                <Action.Push
                  title="View Articles"
                  icon={Icon.List}
                  target={<ArticleList feedId={feed.id} feedTitle={feed.title || feed.url} />}
                />
                <Action
                  title="Refresh Feed"
                  icon={Icon.ArrowClockwise}
                  onAction={() => refreshFeed(feed)}
                  shortcut={{ modifiers: ["cmd"], key: "r" }}
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

      {selectedView === "articles" &&
        articlesData?.map((article) => {
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
                    target={<ArticleDetail article={article} revalidateArticles={revalidateArticles} />}
                  />
                  <Action.OpenInBrowser url={article.url} shortcut={Keyboard.Shortcut.Common.Open} />
                  <Action
                    title={isRead ? "Mark as Unread" : "Mark as Read"}
                    icon={isRead ? Icon.Circle : Icon.Checkmark}
                    onAction={() => toggleArticleRead(article)}
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
