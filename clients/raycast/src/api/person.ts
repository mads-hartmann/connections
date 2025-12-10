import { Alert, confirmAlert } from "@raycast/api";

export interface Person {
  id: number;
  name: string;
}

export interface PersonsResponse {
  data: Person[];
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export function listUrl({ page }: { page: number }) {
  return `http://localhost:8080/persons?page=${page}&per_page=20`;
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
