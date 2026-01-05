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

type ViewType = "connections" | "articles-all" | "articles-unread" | "articles-read-later" | "tags";

interface Preferences {
  serverUrl: string;
  defaultView: ViewType;
}

export default function Command() {
  const preferences = getPreferenceValues<Preferences>();
  const [selectedView, setSelectedView] = useState<ViewType>(preferences.defaultView || "articles-unread");
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

  const isArticlesView =
    selectedView === "articles-all" || selectedView === "articles-unread" || selectedView === "articles-read-later";

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
        readLater: selectedView === "articles-read-later",
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
      case "articles-read-later":
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
            <List.Dropdown.Item title="Read Later" value="articles-read-later" icon={Icon.Clock} />
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
        (() => {
          const withUnread = connectionsData?.filter((p) => p.unread_article_count > 0) ?? [];
          const withoutUnread = connectionsData?.filter((p) => p.unread_article_count === 0) ?? [];
          const totalUnread = withUnread.reduce((sum, p) => sum + p.unread_article_count, 0);

          return (
            <>
              {withUnread.length > 0 && (
                <List.Section title="Unread" subtitle={`${totalUnread} unread articles`}>
                  {withUnread.map((person) => (
                    <PersonListItem
                      key={String(person.id)}
                      person={person}
                      revalidate={revalidateConnections}
                      showDetail={showConnectionsDetail}
                      onToggleDetail={() => setShowConnectionsDetail(!showConnectionsDetail)}
                    />
                  ))}
                </List.Section>
              )}
              {withoutUnread.length > 0 && (
                <List.Section title="All">
                  {withoutUnread.map((person) => (
                    <PersonListItem
                      key={String(person.id)}
                      person={person}
                      revalidate={revalidateConnections}
                      showDetail={showConnectionsDetail}
                      onToggleDetail={() => setShowConnectionsDetail(!showConnectionsDetail)}
                    />
                  ))}
                </List.Section>
              )}
            </>
          );
        })()}

      {isArticlesView &&
        articlesData?.map((article) => (
          <ArticleListItem
            key={String(article.id)}
            article={article}
            revalidate={revalidateArticles}
            showDetail={showArticlesDetail}
            onToggleDetail={() => setShowArticlesDetail(!showArticlesDetail)}
            onMarkAllRead={
              selectedView !== "articles-read-later" ? () => markAllArticlesRead(revalidateArticles) : undefined
            }
          />
        ))}

      {selectedView === "tags" &&
        tagsData?.map((tag) => <TagListItem key={String(tag.id)} tag={tag} revalidate={revalidateTags} />)}
    </List>
  );
}
