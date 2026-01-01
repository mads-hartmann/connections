import { Action, ActionPanel, Icon, Keyboard, List } from "@raycast/api";
import * as Person from "../api/person";
import { AddMetadataForm } from "./add-metadata-form";
import { ArticleList } from "./article-list";
import { PersonCreateForm } from "./person-create-form";
import { FeedList } from "./feed-list";
import { ImportOpml } from "./import-opml";
import { PersonDetailMetadata } from "./person-detail-metadata";
import { PersonEditForm } from "./person-edit-form";

interface PersonItemProps {
  person: Person.Person;
  revalidate: () => void;
  showDetail: boolean;
  onToggleDetail: () => void;
}

export function PersonListItem({ person, revalidate, showDetail, onToggleDetail }: PersonItemProps) {
  const deletePerson = async () => {
    await Person.deletePerson(person);
    revalidate();
  };

  const accessories: List.Item.Accessory[] = [];
  if (person.unread_article_count > 0) {
    accessories.push({ text: `${person.unread_article_count} unread` });
  }

  return (
    <List.Item
      key={String(person.id)}
      title={person.name}
      accessories={accessories}
      detail={<PersonDetailMetadata person={person} />}
      actions={
        <ActionPanel>
          <Action.Push
            title="View Articles"
            icon={Icon.Document}
            target={<ArticleList personId={person.id} personName={person.name} />}
          />
          <Action.Push
            title="View Feeds"
            icon={Icon.List}
            shortcut={{ modifiers: ["cmd"], key: "f" }}
            target={<FeedList personId={person.id} personName={person.name} />}
          />
          <Action.Push
            title="Add Metadata"
            icon={Icon.Plus}
            shortcut={{ modifiers: ["cmd"], key: "m" }}
            target={<AddMetadataForm personId={person.id} personName={person.name} revalidate={revalidate} />}
          />
          <Action.Push
            title="Edit Person"
            icon={Icon.Pencil}
            shortcut={Keyboard.Shortcut.Common.Edit}
            target={<PersonEditForm person={person} revalidate={revalidate} />}
          />
          <Action
            title={showDetail ? "Hide Details" : "Show Details"}
            icon={showDetail ? Icon.EyeDisabled : Icon.Eye}
            shortcut={{ modifiers: ["cmd"], key: "d" }}
            onAction={onToggleDetail}
          />
          <Action.Push
            title="Create Person"
            icon={Icon.Plus}
            shortcut={Keyboard.Shortcut.Common.New}
            target={<PersonCreateForm revalidate={revalidate} />}
          />
          <Action.Push
            title="Import from OPML"
            icon={Icon.Download}
            shortcut={{ modifiers: ["cmd", "shift"], key: "i" }}
            target={<ImportOpml revalidate={revalidate} />}
          />
          <Action
            title="Delete"
            icon={Icon.Trash}
            style={Action.Style.Destructive}
            onAction={deletePerson}
            shortcut={Keyboard.Shortcut.Common.Remove}
          />
        </ActionPanel>
      }
    />
  );
}
