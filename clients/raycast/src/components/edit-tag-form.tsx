import { Action, ActionPanel, Form, showToast, Toast, useNavigation } from "@raycast/api";
import { useState } from "react";
import * as Tag from "../api/tag";

interface EditTagFormProps {
  tag: Tag.Tag;
  revalidate: () => void;
}

export function EditTagForm({ tag, revalidate }: EditTagFormProps) {
  const { pop } = useNavigation();
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(values: { name: string }) {
    const name = values.name.trim();
    if (!name) {
      showToast({
        style: Toast.Style.Failure,
        title: "Name required",
        message: "Please enter a tag name",
      });
      return;
    }

    setIsLoading(true);
    try {
      await Tag.updateTag(tag.id, name);
      showToast({ style: Toast.Style.Success, title: "Tag updated" });
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update tag",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <Form
      isLoading={isLoading}
      navigationTitle="Edit Tag"
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Update Tag" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="name" title="Name" defaultValue={tag.name} placeholder="Enter tag name" autoFocus />
    </Form>
  );
}
