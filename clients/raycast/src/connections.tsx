import { Action, ActionPanel, getPreferenceValues, Icon, Keyboard, List } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState } from "react";
import { markAllArticlesRead } from "./actions/article-actions";
import { PersonCreateForm } from "./components/person-create-form";
import { ImportOpml } from "./components/import-opml";
import { ArticleListItem } from "./components/article-list-item";
import { PersonListItem } from "./components/person-list-item";
import { TagListItem } from "./components/tag-list-item";
import * as Person from "./api/person";
import * as Article from "./api/article";
import * as Tag from "./api/tag";

type ViewType = "connections" | "articles-all" | "articles-unread" | "tags";

interface Preferences {
  serverUrl: string;
  defaultView: "connections" | "articles" | "tags";
}

function defaultViewToViewType(defaultView: Preferences["defaultView"]): ViewType {
  switch (defaultView) {
    case "articles":
      return "articles-unread";
    case "connections":
      return "connections";
    case "tags":
      return "tags";
    default:
      return "connections";
  }
}

export default function Command() {
  const preferences = getPreferenceValues<Preferences>();
  const [selectedView, setSelectedView] = useState<ViewType>(defaultViewToViewType(preferences.defaultView));
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

  const isArticlesView = selectedView === "articles-all" || selectedView === "articles-unread";

  const {
    isLoading: isLoadingArticles,
    data: articlesData,
    pagination: articlesPagination,
    revalidate: revalidateArticles,
  } = useFetch(
    (options) =>
      Article.listAllUrl({
        page: options.page + 1,
        query: searchText || undefined,
        unread: selectedView === "articles-unread",
      }),
    {
      mapResult(result: Article.ArticlesResponse) {
        return {
          data: result.data,
          hasMore: result.page < result.total_pages,
        };
      },
      keepPreviousData: true,
      execute: isArticlesView,
    },
  );

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
      case "articles-all":
      case "articles-unread":
        return {
          isLoading: isLoadingArticles,
          pagination: articlesPagination,
          searchBarPlaceholder: "Search articles...",
        };
      case "connections":
        return {
          isLoading: isLoadingConnections,
          pagination: connectionsPagination,
          searchBarPlaceholder: "Search people...",
        };
      case "tags":
        return { isLoading: isLoadingTags, pagination: tagsPagination, searchBarPlaceholder: "Search tags..." };
    }
  })();

  return (
    <List
      isLoading={isLoading}
      pagination={pagination}
      filtering={false}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder={searchBarPlaceholder}
      isShowingDetail={
        (selectedView === "connections" && showConnectionsDetail) || (isArticlesView && showArticlesDetail)
      }
      searchBarAccessory={
        <List.Dropdown
          tooltip="Select View"
          value={selectedView}
          onChange={(value) => setSelectedView(value as ViewType)}
        >
          <List.Dropdown.Item title="Connections" value="connections" icon={Icon.TwoPeople} />
          <List.Dropdown.Item title="Tags" value="tags" icon={Icon.Tag} />
          <List.Dropdown.Section title="Articles">
            <List.Dropdown.Item title="All" value="articles-all" icon={Icon.Document} />
            <List.Dropdown.Item title="Unread" value="articles-unread" icon={Icon.Circle} />
          </List.Dropdown.Section>
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

      {isArticlesView &&
        articlesData?.map((article) => (
          <ArticleListItem
            key={String(article.id)}
            article={article}
            revalidate={revalidateArticles}
            showDetail={showArticlesDetail}
            onToggleDetail={() => setShowArticlesDetail(!showArticlesDetail)}
            onMarkAllRead={() => markAllArticlesRead(revalidateArticles)}
          />
        ))}

      {selectedView === "tags" &&
        tagsData?.map((tag) => <TagListItem key={String(tag.id)} tag={tag} revalidate={revalidateTags} />)}
    </List>
  );
}
