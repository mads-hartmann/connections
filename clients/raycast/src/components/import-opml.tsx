import { Action, ActionPanel, Form, Icon, List, showToast, Toast, useNavigation } from "@raycast/api";
import { useState } from "react";
import * as Import from "../api/import";

interface ImportOpmlProps {
  revalidate: () => void;
}

// Step 1: File picker form
export function ImportOpml({ revalidate }: ImportOpmlProps) {
  const { push } = useNavigation();
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(values: { file: string[] }) {
    if (!values.file || values.file.length === 0) {
      showToast({
        style: Toast.Style.Failure,
        title: "No file selected",
        message: "Please select an OPML file",
      });
      return;
    }

    setIsLoading(true);
    try {
      // Read file content
      const fs = await import("fs").then((m) => m.promises);
      const content = await fs.readFile(values.file[0], "utf-8");

      // Get preview from API
      const preview = await Import.previewOpml(content);

      if (preview.people.length === 0) {
        showToast({
          style: Toast.Style.Failure,
          title: "No feeds found",
          message:
            preview.errors.length > 0
              ? `${preview.errors.length} feeds failed to load`
              : "The OPML file contains no valid feeds",
        });
        return;
      }

      // Navigate to preview screen
      push(<ImportPreview preview={preview} revalidate={revalidate} />);
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to parse OPML",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <Form
      isLoading={isLoading}
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Preview Import" onSubmit={handleSubmit} icon={Icon.Eye} />
        </ActionPanel>
      }
    >
      <Form.FilePicker id="file" title="OPML File" allowMultipleSelection={false} canChooseDirectories={false} />
      <Form.Description text="Select an OPML file exported from your RSS reader. The import will extract author information from each feed and group them by person." />
    </Form>
  );
}

// Step 2: Preview and select people to import
interface ImportPreviewProps {
  preview: Import.PreviewResponse;
  revalidate: () => void;
}

function ImportPreview({ preview, revalidate }: ImportPreviewProps) {
  const { pop } = useNavigation();
  const [selectedPeople, setSelectedPeople] = useState<Set<string>>(new Set(preview.people.map((p) => p.name)));
  const [isImporting, setIsImporting] = useState(false);

  const togglePerson = (name: string) => {
    const newSelected = new Set(selectedPeople);
    if (newSelected.has(name)) {
      newSelected.delete(name);
    } else {
      newSelected.add(name);
    }
    setSelectedPeople(newSelected);
  };

  const toggleAll = () => {
    if (selectedPeople.size === preview.people.length) {
      setSelectedPeople(new Set());
    } else {
      setSelectedPeople(new Set(preview.people.map((p) => p.name)));
    }
  };

  const handleImport = async () => {
    const peopleToImport = preview.people.filter((p) => selectedPeople.has(p.name));
    if (peopleToImport.length === 0) {
      showToast({
        style: Toast.Style.Failure,
        title: "No people selected",
        message: "Please select at least one person to import",
      });
      return;
    }

    setIsImporting(true);
    try {
      const result = await Import.confirmImport({ people: peopleToImport });
      showToast({
        style: Toast.Style.Success,
        title: "Import complete",
        message: `Created ${result.created_people} people, ${result.created_feeds} feeds, ${result.created_categories} categories`,
      });
      revalidate();
      pop();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Import failed",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsImporting(false);
    }
  };

  return (
    <List isLoading={isImporting} navigationTitle="Import Preview" searchBarPlaceholder="Filter people...">
      <List.Section title="People to Import" subtitle={`${selectedPeople.size} of ${preview.people.length} selected`}>
        {preview.people.map((person) => (
          <List.Item
            key={person.name}
            title={person.name}
            subtitle={`${person.feeds.length} feed${person.feeds.length !== 1 ? "s" : ""}`}
            accessories={[
              ...(person.categories.length > 0 ? [{ tag: person.categories.join(", ") }] : []),
              {
                icon: selectedPeople.has(person.name) ? Icon.CheckCircle : Icon.Circle,
              },
            ]}
            actions={
              <ActionPanel>
                <Action
                  title={selectedPeople.has(person.name) ? "Deselect" : "Select"}
                  icon={selectedPeople.has(person.name) ? Icon.Circle : Icon.CheckCircle}
                  onAction={() => togglePerson(person.name)}
                />
                <Action
                  title={selectedPeople.size === preview.people.length ? "Deselect All" : "Select All"}
                  icon={Icon.CheckCircle}
                  onAction={toggleAll}
                />
                <Action title={`Import ${selectedPeople.size} People`} icon={Icon.Download} onAction={handleImport} />
                <Action.Push title="View Feeds" icon={Icon.List} target={<PersonFeedsList person={person} />} />
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
      {preview.errors.length > 0 && (
        <List.Section title="Failed Feeds" subtitle={`${preview.errors.length} errors`}>
          {preview.errors.map((error) => (
            <List.Item key={error.url} title={error.url} subtitle={error.error} icon={Icon.ExclamationMark} />
          ))}
        </List.Section>
      )}
    </List>
  );
}

// Detail view for a person's feeds
interface PersonFeedsListProps {
  person: Import.PersonInfo;
}

function PersonFeedsList({ person }: PersonFeedsListProps) {
  return (
    <List navigationTitle={`${person.name}'s Feeds`}>
      <List.Section title="Feeds" subtitle={`${person.feeds.length} total`}>
        {person.feeds.map((feed) => (
          <List.Item
            key={feed.url}
            title={feed.title || feed.url}
            subtitle={feed.title ? feed.url : undefined}
            icon={Icon.Link}
          />
        ))}
      </List.Section>
      {person.categories.length > 0 && (
        <List.Section title="Categories">
          {person.categories.map((category) => (
            <List.Item key={category} title={category} icon={Icon.Tag} />
          ))}
        </List.Section>
      )}
    </List>
  );
}
