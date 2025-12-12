import { Alert, confirmAlert } from "@raycast/api";

export interface Person {
  id: number;
  name: string;
  feed_count: number;
  article_count: number;
}

export interface PersonsResponse {
  data: Person[];
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export function listUrl({ page, query }: { page: number; query?: string }) {
  const params = new URLSearchParams({ page: String(page), per_page: "20" });
  if (query) {
    params.append("query", query);
  }
  return `http://localhost:8080/persons?${params.toString()}`;
}

export async function deletePerson(person: Person) {
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
  }
}
