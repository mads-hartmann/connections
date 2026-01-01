import { Action, ActionPanel, Icon, Keyboard, List, showToast, Toast } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState, useCallback } from "react";
import { PersonCreateForm } from "./components/person-create-form";
import { FeedListItem } from "./components/feed-list-item";
import { ImportOpml } from "./components/import-opml";
import { ArticleListItem } from "./components/article-list-item";
import { PersonListItem } from "./components/person-list-item";
import { TagListItem } from "./components/tag-list-item";
import * as Person from "./api/person";
import * as Feed from "./api/feed";
import * as Article from "./api/article";
import * as Tag from "./api/tag";

type ViewType = "connections" | "feeds" | "articles" | "tags";

export default function Command() {
  const [selectedView, setSelectedView] = useState<ViewType>("connections");
  const [searchText, setSearchText] = useState("");
  const [showConnectionsDetail, setShowConnectionsDetail] = useState(true);
  const [showArticlesDetail, setShowArticlesDetail] = useState(true);

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

  const {
    isLoading: isLoadingFeeds,
    data: feedsData,
    pagination: feedsPagination,
    revalidate: revalidateFeeds,
  } = useFetch((options) => Feed.listAllUrl({ page: options.page + 1, query: searchText || undefined }), {
    mapResult(result: Feed.FeedsResponse) {
      return {
        data: result.data,
        hasMore: result.page < result.total_pages,
      };
    },
    keepPreviousData: true,
    execute: selectedView === "feeds",
  });

  const {
    isLoading: isLoadingArticles,
    data: articlesData,
    pagination: articlesPagination,
    revalidate: revalidateArticles,
  } = useFetch((options) => Article.listAllUrl({ page: options.page + 1, query: searchText || undefined }), {
    mapResult(result: Article.ArticlesResponse) {
      return {
        data: result.data,
        hasMore: result.page < result.total_pages,
      };
    },
    keepPreviousData: true,
    execute: selectedView === "articles",
  });

  const {
    isLoading: isLoadingTags,
    data: tagsData,
    pagination: tagsPagination,
    revalidate: revalidateTags,
  } = useFetch((options) => Tag.listUrl({ page: options.page + 1, query: searchText || undefined }), {
    mapResult(result: Tag.TagsResponse) {
      return {
        data: result.data,
        hasMore: result.page < result.total_pages,
      };
    },
    keepPreviousData: true,
    execute: selectedView === "tags",
  });

  const { isLoading, pagination, searchBarPlaceholder } = (() => {
    switch (selectedView) {
      case "articles":
        return {isLoading: isLoadingArticles, pagination: articlesPagination, searchBarPlaceholder: "Search articles..."}
      case "connections":
        return {isLoading: isLoadingConnections, pagination: connectionsPagination, searchBarPlaceholder: "Search people..."}
      case "feeds":
        return {isLoading: isLoadingFeeds, pagination: feedsPagination, searchBarPlaceholder: "Search feeds..."}
      case "tags":
        return {isLoading: isLoadingTags, pagination: tagsPagination, searchBarPlaceholder: "Search tags..."}
    }
  })()

  return (
    <List
      isLoading={isLoading}
      pagination={pagination}
      filtering={false}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder={searchBarPlaceholder}
      isShowingDetail={(selectedView === "connections" && showConnectionsDetail) || (selectedView === "articles" && showArticlesDetail)}
      searchBarAccessory={
        <List.Dropdown
          tooltip="Select View"
          value={selectedView}
          onChange={(value) => setSelectedView(value as ViewType)}
        >
          <List.Dropdown.Item title="Connections" value="connections" />
          <List.Dropdown.Item title="Feeds" value="feeds" />
          <List.Dropdown.Item title="Articles" value="articles" />
          <List.Dropdown.Item title="Tags" value="tags" />
        </List.Dropdown>
      }
      actions={
        selectedView === "connections" ? (
          <ActionPanel>
            <Action.Push
              title="Create Person"
              icon={Icon.Plus}
              shortcut={Keyboard.Shortcut.Common.New}
              target={<PersonCreateForm revalidate={revalidateConnections} />}
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
          <PersonListItem
            key={String(person.id)}
            person={person}
            revalidate={revalidateConnections}
            showDetail={showConnectionsDetail}
            onToggleDetail={() => setShowConnectionsDetail(!showConnectionsDetail)}
          />
        ))}

      {selectedView === "feeds" &&
        feedsData?.map((feed) => <FeedListItem key={String(feed.id)} feed={feed} revalidate={revalidateFeeds} />)}

      {selectedView === "articles" &&
        articlesData?.map((article) => (
          <ArticleListItem
            key={String(article.id)}
            article={article}
            revalidate={revalidateArticles}
            showDetail={showArticlesDetail}
            onToggleDetail={() => setShowArticlesDetail(!showArticlesDetail)}
            onMarkAllRead={async () => {
              try {
                const result = await Article.markAllArticlesReadGlobal();
                await showToast({
                  style: Toast.Style.Success,
                  title: `Marked ${result.marked_read} articles as read`,
                });
                revalidateArticles();
              } catch (error) {
                await showToast({
                  style: Toast.Style.Failure,
                  title: "Failed to mark all as read",
                  message: error instanceof Error ? error.message : "Unknown error",
                });
              }
            }}
          />
        ))}

      {selectedView === "tags" &&
        tagsData?.map((tag) => <TagListItem key={String(tag.id)} tag={tag} revalidate={revalidateTags} />)}
    </List>
  );
}
