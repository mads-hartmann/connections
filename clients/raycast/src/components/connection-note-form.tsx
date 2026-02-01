import { Action, ActionPanel, Form, Icon, showToast, Toast, useNavigation } from "@raycast/api";
import { useState } from "react";
import * as Connection from "../api/connection";

interface ConnectionNoteFormProps {
  connection: Connection.Connection;
  revalidate: () => void;
}

export function ConnectionNoteForm({ connection, revalidate }: ConnectionNoteFormProps) {
  const { pop } = useNavigation();
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(values: { note: string }) {
    setIsSubmitting(true);
    try {
      const note = values.note.trim() || null;
      await Connection.updateConnectionNote(connection.id, note);
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
      navigationTitle={`Edit Note - ${connection.name}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Save Note" icon={Icon.Check} onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextArea
        id="note"
        title="Note"
        defaultValue={connection.note || ""}
        placeholder="Add a note about this connection..."
      />
    </Form>
  );
}
