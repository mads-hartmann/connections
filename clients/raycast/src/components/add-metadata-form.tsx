import { Action, ActionPanel, Form, showToast, Toast, useNavigation } from "@raycast/api";
import { useState } from "react";
import { createMetadata, FIELD_TYPES } from "../api/connection";

interface AddMetadataFormProps {
  connectionId: number;
  connectionName: string;
  revalidate: () => void;
}

export function AddMetadataForm({ connectionId, connectionName, revalidate }: AddMetadataFormProps) {
  const { pop } = useNavigation();
  const [isLoading, setIsLoading] = useState(false);
  const [fieldTypeId, setFieldTypeId] = useState(String(FIELD_TYPES[0].id));
  const [value, setValue] = useState("");

  const handleSubmit = async () => {
    if (!value.trim()) {
      showToast({ style: Toast.Style.Failure, title: "Value is required" });
      return;
    }

    setIsLoading(true);
    try {
      await createMetadata(connectionId, parseInt(fieldTypeId), value.trim());
      showToast({ style: Toast.Style.Success, title: "Metadata added" });
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to add metadata",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Form
      isLoading={isLoading}
      navigationTitle={`Add Metadata to ${connectionName}`}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Add Metadata" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.Dropdown id="fieldType" title="Type" value={fieldTypeId} onChange={setFieldTypeId}>
        {FIELD_TYPES.map((type) => (
          <Form.Dropdown.Item key={type.id} value={String(type.id)} title={type.name} />
        ))}
      </Form.Dropdown>
      <Form.TextField
        id="value"
        title="Value"
        placeholder="https://example.com or user@example.com"
        value={value}
        onChange={setValue}
      />
    </Form>
  );
}
