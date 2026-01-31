import { Action, ActionPanel, getPreferenceValues, Icon, Keyboard, List } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState } from "react";
import { markAllUrisRead } from "./actions/uri-actions";
import { ConnectionCreateForm } from "./components/connection-create-form";
import { ImportOpml } from "./components/import-opml";
import { UriListItem } from "./components/uri-list-item";
import { ConnectionListItem } from "./components/connection-list-item";
import { TagListItem } from "./components/tag-list-item";
import * as Connection from "./api/connection";
import * as Uri from "./api/uri";
import * as Tag from "./api/tag";

type ViewType = "connections" | "uris-all" | "uris-unread" | "uris-read-later" | "tags";

interface Preferences {
  serverUrl: string;
  defaultView: ViewType;
}

export default function Command() {
  const preferences = getPreferenceValues<Preferences>();
  const [selectedView, setSelectedView] = useState<ViewType>(preferences.defaultView || "uris-unread");
  const [searchText, setSearchText] = useState("");
  const [showConnectionsDetail, setShowConnectionsDetail] = useState(true);
  const [showUrisDetail, setShowUrisDetail] = useState(true);

  const {
    isLoading: isLoadingConnections,
    data: connectionsData,
    pagination: connectionsPagination,
    revalidate: revalidateConnections,
  } = useFetch((options) => Connection.listUrl({ page: options.page + 1, query: searchText || undefined }), {
    mapResult(result: Connection.ConnectionsResponse) {
      return {
        data: result.data,
        hasMore: result.page < result.total_pages,
      };
    },
    keepPreviousData: true,
    execute: selectedView === "connections",
  });

  const isUrisView =
    selectedView === "uris-all" || selectedView === "uris-unread" || selectedView === "uris-read-later";

  const {
    isLoading: isLoadingUris,
    data: urisData,
    pagination: urisPagination,
    revalidate: revalidateUris,
  } = useFetch(
    (options) =>
      Uri.listAllUrl({
        page: options.page + 1,
        query: searchText || undefined,
        unread: selectedView === "uris-unread",
        readLater: selectedView === "uris-read-later",
      }),
    {
      mapResult(result: Uri.UrisResponse) {
        return {
          data: result.data,
          hasMore: result.page < result.total_pages,
        };
      },
      keepPreviousData: true,
      execute: isUrisView,
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
      case "uris-all":
      case "uris-unread":
      case "uris-read-later":
        return {
          isLoading: isLoadingUris,
          pagination: urisPagination,
          searchBarPlaceholder: "Search URIs...",
        };
      case "connections":
        return {
          isLoading: isLoadingConnections,
          pagination: connectionsPagination,
          searchBarPlaceholder: "Search connections...",
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
      isShowingDetail={(selectedView === "connections" && showConnectionsDetail) || (isUrisView && showUrisDetail)}
      searchBarAccessory={
        <List.Dropdown
          tooltip="Select View"
          value={selectedView}
          onChange={(value) => setSelectedView(value as ViewType)}
        >
          <List.Dropdown.Item title="Connections" value="connections" icon={Icon.TwoPeople} />
          <List.Dropdown.Item title="Tags" value="tags" icon={Icon.Tag} />
          <List.Dropdown.Section title="URIs">
            <List.Dropdown.Item title="All" value="uris-all" icon={Icon.Document} />
            <List.Dropdown.Item title="Unread" value="uris-unread" icon={Icon.Circle} />
            <List.Dropdown.Item title="Read Later" value="uris-read-later" icon={Icon.Clock} />
          </List.Dropdown.Section>
        </List.Dropdown>
      }
      actions={
        selectedView === "connections" ? (
          <ActionPanel>
            <Action.Push
              title="Create Connection"
              icon={Icon.Plus}
              shortcut={Keyboard.Shortcut.Common.New}
              target={<ConnectionCreateForm revalidate={revalidateConnections} />}
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
          const withUnread = connectionsData?.filter((c) => c.unread_uri_count > 0) ?? [];
          const withoutUnread = connectionsData?.filter((c) => c.unread_uri_count === 0) ?? [];
          const totalUnread = withUnread.reduce((sum, c) => sum + c.unread_uri_count, 0);

          return (
            <>
              {withUnread.length > 0 && (
                <List.Section title="Unread" subtitle={`${totalUnread} unread URIs`}>
                  {withUnread.map((connection) => (
                    <ConnectionListItem
                      key={String(connection.id)}
                      connection={connection}
                      revalidate={revalidateConnections}
                      showDetail={showConnectionsDetail}
                      onToggleDetail={() => setShowConnectionsDetail(!showConnectionsDetail)}
                    />
                  ))}
                </List.Section>
              )}
              {withoutUnread.length > 0 && (
                <List.Section title="All">
                  {withoutUnread.map((connection) => (
                    <ConnectionListItem
                      key={String(connection.id)}
                      connection={connection}
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

      {isUrisView &&
        urisData?.map((uri) => (
          <UriListItem
            key={String(uri.id)}
            uri={uri}
            revalidate={revalidateUris}
            showDetail={showUrisDetail}
            onToggleDetail={() => setShowUrisDetail(!showUrisDetail)}
            onMarkAllRead={selectedView !== "uris-read-later" ? () => markAllUrisRead(revalidateUris) : undefined}
          />
        ))}

      {selectedView === "tags" &&
        tagsData?.map((tag) => <TagListItem key={String(tag.id)} tag={tag} revalidate={revalidateTags} />)}
    </List>
  );
}
