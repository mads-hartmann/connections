import { Action, ActionPanel, Icon, Keyboard, List } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { useState } from "react";
import { CreatePersonForm } from "./components/create-person-form";
import { FeedList } from "./components/feed-list";
import { ImportOpml } from "./components/import-opml";
import * as Person from "./api/person";

export default function Command() {
  const [searchText, setSearchText] = useState("");

  const { isLoading, data, pagination, revalidate } = useFetch(
    (options) => Person.listUrl({ page: options.page + 1, query: searchText || undefined }),
    {
      mapResult(result: Person.PersonsResponse) {
        return {
          data: result.data,
          hasMore: result.page < result.total_pages,
        };
      },
      keepPreviousData: true,
    },
  );

  const deletePerson = async (person: Person.Person) => {
    await Person.deletePerson(person);
    revalidate();
  };

  return (
    <List
      isLoading={isLoading}
      pagination={pagination}
      filtering={false}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder="Search people..."
      actions={
        <ActionPanel>
          <Action.Push
            title="Create Person"
            icon={Icon.Plus}
            shortcut={Keyboard.Shortcut.Common.New}
            target={<CreatePersonForm revalidate={revalidate} />}
          />
          <Action.Push
            title="Import from OPML"
            icon={Icon.Download}
            shortcut={{ modifiers: ["cmd", "shift"], key: "i" }}
            target={<ImportOpml revalidate={revalidate} />}
          />
        </ActionPanel>
      }
    >
      {data?.map((person) => (
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
                target={<CreatePersonForm revalidate={revalidate} />}
              />
              <Action.Push
                title="Import from OPML"
                icon={Icon.Download}
                shortcut={{ modifiers: ["cmd", "shift"], key: "i" }}
                target={<ImportOpml revalidate={revalidate} />}
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
    </List>
  );
}
