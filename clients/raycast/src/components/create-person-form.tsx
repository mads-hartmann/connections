import { Action, ActionPanel, Form, useNavigation } from "@raycast/api";

export function CreatePersonForm({ revalidate }: { revalidate: () => void }) {
  const { pop } = useNavigation();

  async function handleSubmit(values: { name: string }) {
    await fetch("http://localhost:8080/persons", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: values.name }),
    });
    revalidate();
    pop();
  }

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Create Person" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="name" title="Name" placeholder="Enter person's name" />
    </Form>
  );
}
