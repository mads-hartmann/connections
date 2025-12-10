import { Action, ActionPanel, Alert, confirmAlert, Icon, List } from "@raycast/api";
import { useFetch } from "@raycast/utils";

interface Person {
  id: number;
  name: string;
}

interface PersonsResponse {
  data: Person[];
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export default function Command() {
  const { isLoading, data, pagination, revalidate } = useFetch(
    (options) => `http://localhost:8080/persons?page=${options.page + 1}&per_page=20`,
    {
      mapResult(result: PersonsResponse) {
        return {
          data: result.data,
          hasMore: result.page < result.total_pages,
        };
      },
    },
  );

  async function deletePerson(person: Person) {
    if (
      await confirmAlert({
        title: "Delete Person",
        message: `Are you sure you want to delete "${person.name}"?`,
        primaryAction: {
          title: "Delete",
          style: Alert.ActionStyle.Destructive,
        },
      })
    ) {
      await fetch(`http://localhost:8080/persons/${person.id}`, {
        method: "DELETE",
      });
      revalidate();
    }
  }

  return (
    <List isLoading={isLoading} pagination={pagination}>
      {data?.map((person) => (
        <List.Item
          key={String(person.id)}
          title={person.name}
          actions={
            <ActionPanel>
              <Action
                title="Delete"
                icon={Icon.Trash}
                style={Action.Style.Destructive}
                onAction={() => deletePerson(person)}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
