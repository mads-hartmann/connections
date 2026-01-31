import { List } from "@raycast/api";
import * as Connection from "../api/connection";

function getMetadataUrl(metadata: Connection.ConnectionMetadata): string | null {
  const value = metadata.value;
  if (metadata.field_type.name === "Email") {
    return `mailto:${value}`;
  }
  if (value.startsWith("http://") || value.startsWith("https://")) {
    return value;
  }
  return null;
}

interface ConnectionDetailMetadataProps {
  connection: Connection.Connection;
}

export function ConnectionDetailMetadata({ connection }: ConnectionDetailMetadataProps) {
  const tags = connection.tags;
  return (
    <List.Item.Detail
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.Label title="Name" text={connection.name} />
          <List.Item.Detail.Metadata.Label title="Feeds" text={String(connection.feed_count)} />
          <List.Item.Detail.Metadata.Label title="URIs" text={String(connection.uri_count)} />
          {tags && tags.length > 0 && (
            <List.Item.Detail.Metadata.TagList title="Tags">
              {tags.map((tag) => (
                <List.Item.Detail.Metadata.TagList.Item key={tag.id} text={tag.name} />
              ))}
            </List.Item.Detail.Metadata.TagList>
          )}
          {connection.metadata.length > 0 && <List.Item.Detail.Metadata.Separator />}
          {connection.metadata.map((m) => {
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
