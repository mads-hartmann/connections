import { Action, ActionPanel, Icon, List } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import * as Tag from "../api/tag";
import { TagArticles } from "./tag-articles";

export function TagList() {
  const { isLoading, data, pagination } = useFetch((options) => Tag.listUrl({ page: options.page + 1 }), {
    mapResult(result: Tag.TagsResponse) {
      return {
        data: result.data,
        hasMore: result.page < result.total_pages,
      };
    },
    keepPreviousData: true,
  });

  return (
    <List isLoading={isLoading} pagination={pagination} navigationTitle="Tags">
      {data?.map((tag) => (
        <List.Item
          key={String(tag.id)}
          title={tag.name}
          icon={Icon.Tag}
          actions={
            <ActionPanel>
              <Action.Push title="View Articles" icon={Icon.List} target={<TagArticles tag={tag} />} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
