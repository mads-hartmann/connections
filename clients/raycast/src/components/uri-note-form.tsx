import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useState } from "react";
import * as Uri from "../api/uri";

interface UriNoteFormProps {
  uri: Uri.Uri;
  revalidate: () => void;
}

export function UriNoteForm({ uri, revalidate }: UriNoteFormProps) {
  const { pop } = useNavigation();
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(values: { note: string }) {
    setIsSubmitting(true);
    try {
      const note = values.note.trim() || null;
      await Uri.updateUriNote(uri.id, note);
      showToast({ style: Toast.Style.Success, title: "Note updated" });
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to update note",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Form
      isLoading={isSubmitting}
      navigationTitle={`Edit Note - ${uri.title || "Untitled"}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Save Note" icon={Icon.Check} onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextArea
        id="note"
        title="Note"
        defaultValue={uri.note || ""}
        placeholder="Add a note about this URI..."
      />
    </Form>
  );
}
