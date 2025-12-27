import { List } from "@raycast/api";
import * as Person from "../api/person";

function getMetadataUrl(metadata: Person.PersonMetadata): string | null {
  const value = metadata.value;
  if (metadata.field_type.name === "Email") {
    return `mailto:${value}`;
  }
  if (value.startsWith("http://") || value.startsWith("https://")) {
    return value;
  }
  return null;
}

interface PersonDetailMetadataProps {
  person: Person.Person;
}

export function PersonDetailMetadata({ person }: PersonDetailMetadataProps) {
  const tags = person.tags
  return (
    <List.Item.Detail
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.Label title="Name" text={person.name} />
          <List.Item.Detail.Metadata.Label title="Feeds" text={String(person.feed_count)} />
          <List.Item.Detail.Metadata.Label title="Articles" text={String(person.article_count)} />
          {tags && tags.length > 0 && (
            <List.Item.Detail.Metadata.TagList title="Tags">
              {tags.map((tag) => (
                <List.Item.Detail.Metadata.TagList.Item key={tag.id} text={tag.name} />
              ))}
            </List.Item.Detail.Metadata.TagList>
          )}
          {person.metadata.length > 0 && <List.Item.Detail.Metadata.Separator />}
          {person.metadata.map((m) => {
            const url = getMetadataUrl(m);
            if (url) {
              return (
                <List.Item.Detail.Metadata.Link key={m.id} title={m.field_type.name} text={m.value} target={url} />
              );
            }
            return <List.Item.Detail.Metadata.Label key={m.id} title={m.field_type.name} text={m.value} />;
          })}
        </List.Item.Detail.Metadata>
      }
    />
  );
}
