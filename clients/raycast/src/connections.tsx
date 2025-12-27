import { Action, ActionPanel, Icon, Keyboard, List } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState } from "react";
import { CreatePersonForm } from "./components/create-person-form";
import { FeedList } from "./components/feed-list";
import { FeedItem } from "./components/feed-item";
import { ImportOpml } from "./components/import-opml";
import { ArticleList } from "./components/article-list";
import { ArticleItem } from "./components/article-item";
import { AddMetadataForm } from "./components/add-metadata-form";
import { CreateTagForm } from "./components/create-tag-form";
import { EditTagForm } from "./components/edit-tag-form";
import { PersonEditForm } from "./components/person-edit-form";
import { PersonDetailMetadata } from "./components/person-detail-metadata";
import * as Person from "./api/person";
import * as Feed from "./api/feed";
import * as Article from "./api/article";
import * as Tag from "./api/tag";

type ViewType = "connections" | "feeds" | "articles" | "tags";

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "";
  const date = new Date(dateStr);
  return date.toLocaleDateString();
}

export default function Command() {
  const [selectedView, setSelectedView] = useState<ViewType>("connections");
  const [searchText, setSearchText] = useState("");
  const [showConnectionsDetail, setShowConnectionsDetail] = useState(true);
  const [showArticlesDetail, setShowArticlesDetail] = useState(true);

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

  // Fetch all articles
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

  // Fetch all tags
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

  const deletePerson = async (person: Person.Person) => {
    await Person.deletePerson(person);
    revalidateConnections();
  };

  // Determine current loading state and pagination based on selected view
  const isLoading =
    selectedView === "connections"
      ? isLoadingConnections
      : selectedView === "feeds"
        ? isLoadingFeeds
        : selectedView === "articles"
          ? isLoadingArticles
          : isLoadingTags;

  const pagination =
    selectedView === "connections"
      ? connectionsPagination
      : selectedView === "feeds"
        ? feedsPagination
        : selectedView === "articles"
          ? articlesPagination
          : tagsPagination;

  const searchBarPlaceholder =
    selectedView === "connections"
      ? "Search people..."
      : selectedView === "feeds"
        ? "Search feeds..."
        : selectedView === "articles"
          ? "Search articles..."
          : "Search tags...";

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
            detail={<PersonDetailMetadata person={person} />}
            actions={
              <ActionPanel>
                <Action.Push
                  title="View Feeds"
                  icon={Icon.List}
                  target={<FeedList personId={person.id} personName={person.name} />}
                />
                <Action.Push
                  title="Add Metadata"
                  icon={Icon.Plus}
                  shortcut={{ modifiers: ["cmd"], key: "m" }}
                  target={
                    <AddMetadataForm personId={person.id} personName={person.name} revalidate={revalidateConnections} />
                  }
                />
                <Action.Push
                  title="Edit Person"
                  icon={Icon.Pencil}
                  shortcut={Keyboard.Shortcut.Common.Edit}
                  target={<PersonEditForm person={person} revalidate={revalidateConnections} />}
                />
                <Action
                  title={showConnectionsDetail ? "Hide Details" : "Show Details"}
                  icon={showConnectionsDetail ? Icon.EyeDisabled : Icon.Eye}
                  shortcut={{ modifiers: ["cmd"], key: "d" }}
                  onAction={() => setShowConnectionsDetail(!showConnectionsDetail)}
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
        feedsData?.map((feed) => <FeedItem key={String(feed.id)} feed={feed} revalidate={revalidateFeeds} />)}

      {selectedView === "articles" &&
        articlesData?.map((article) => (
          <ArticleItem
            key={String(article.id)}
            article={article}
            revalidate={revalidateArticles}
            showDetail={showArticlesDetail}
            onToggleDetail={() => setShowArticlesDetail(!showArticlesDetail)}
          />
        ))}

      {selectedView === "tags" &&
        tagsData?.map((tag) => (
          <List.Item
            key={String(tag.id)}
            title={tag.name}
            icon={Icon.Tag}
            actions={
              <ActionPanel>
                <Action.Push title="View Articles" icon={Icon.List} target={<ArticleList tag={tag} />} />
                <Action.Push
                  title="Edit Tag"
                  icon={Icon.Pencil}
                  shortcut={Keyboard.Shortcut.Common.Edit}
                  target={<EditTagForm tag={tag} revalidate={revalidateTags} />}
                />
                <Action.Push
                  title="Create Tag"
                  icon={Icon.Plus}
                  shortcut={Keyboard.Shortcut.Common.New}
                  target={<CreateTagForm revalidate={revalidateTags} />}
                />
                <Action
                  title="Delete"
                  icon={Icon.Trash}
                  style={Action.Style.Destructive}
                  onAction={async () => {
                    const deleted = await Tag.deleteTag(tag);
                    if (deleted) {
                      revalidateTags();
                    }
                  }}
                  shortcut={Keyboard.Shortcut.Common.Remove}
                />
              </ActionPanel>
            }
          />
        ))}
    </List>
  );
}
