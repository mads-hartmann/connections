import { Action, ActionPanel, Form, showToast, Toast, useNavigation } from "@raycast/api";
import * as Feed from "../api/feed";

interface CreateFeedFormProps {
  personId: number;
  revalidate: () => void;
}

export function CreateFeedForm({ personId, revalidate }: CreateFeedFormProps) {
  const { pop } = useNavigation();

  async function handleSubmit(values: { url: string; title: string }) {
    try {
      await Feed.createFeed(personId, values.url, values.title);
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to create feed",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Create Feed" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="url" title="URL" placeholder="https://example.com/feed.xml" />
      <Form.TextField id="title" title="Title" placeholder="Feed title" />
    </Form>
  );
}
