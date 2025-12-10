import { Action, ActionPanel, Icon, Keyboard, List } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import { CreatePersonForm } from "./components/create-person-form";
import * as Person from "./api/person";

export default function Command() {
  const { isLoading, data, pagination, revalidate } = useFetch(
    (options) => Person.listUrl({ page: options.page + 1 }),
    {
      mapResult(result: Person.PersonsResponse) {
        return {
          data: result.data,
          hasMore: result.page < result.total_pages,
        };
      },
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
      actions={
        <ActionPanel>
          <Action.Push
            title="Create Person"
            icon={Icon.Plus}
            shortcut={Keyboard.Shortcut.Common.New}
            target={<CreatePersonForm revalidate={revalidate} />}
          />
        </ActionPanel>
      }
    >
      {data?.map((person) => (
        <List.Item
          key={String(person.id)}
          title={person.name}
          actions={
            <ActionPanel>
              <Action.Push
                title="Create Person"
                icon={Icon.Plus}
                shortcut={Keyboard.Shortcut.Common.New}
                target={<CreatePersonForm revalidate={revalidate} />}
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
