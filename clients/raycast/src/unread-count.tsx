import { Icon, MenuBarExtra, open, launchCommand, LaunchType, showToast, Toast } from "@raycast/api";
import { useFetch } from "@raycast/utils";
import * as Article from "./api/article";

export default function Command() {
  const {
    isLoading,
    data,
    error,
    revalidate,
  } = useFetch<Article.ArticlesResponse>(
    Article.listAllUrl({ page: 1, unread: true }),
    {
      keepPreviousData: true,
    }
  );

  const unreadCount = data?.total ?? 0;
  const recentArticles = data?.data.slice(0, 5) ?? [];

  const handleArticleClick = async (article: Article.Article) => {
    try {
      await Article.markArticleRead(article.id, true);
      await open(article.url);
      revalidate();
    } catch (e) {
      await showToast({ style: Toast.Style.Failure, title: "Failed to mark as read" });
      await open(article.url);
    }
  };

  const handleMarkAllRead = async () => {
    try {
      const result = await Article.markAllArticlesReadGlobal();
      await showToast({
        style: Toast.Style.Success,
        title: `Marked ${result.marked_read} articles as read`,
      });
      revalidate();
    } catch (e) {
      await showToast({ style: Toast.Style.Failure, title: "Failed to mark all as read" });
    }
  };

  const title = error ? undefined : String(unreadCount);

  return (
    <MenuBarExtra
      icon={Icon.Person}
      title={title}
      isLoading={isLoading}
    >
      {error ? (
        <MenuBarExtra.Item
          title={`Error: ${error.message}`}
          onAction={() => revalidate()}
        />
      ) : (
        <>
          <MenuBarExtra.Section title="Recent Unread">
            {recentArticles.length === 0 ? (
              <MenuBarExtra.Item title="No unread articles" />
            ) : (
              recentArticles.map((article) => (
                <MenuBarExtra.Item
                  key={article.id}
                  title={article.title ?? article.url}
                  subtitle={article.author ?? undefined}
                  onAction={() => handleArticleClick(article)}
                />
              ))
            )}
          </MenuBarExtra.Section>

          <MenuBarExtra.Section>
            {unreadCount > 0 && (
              <MenuBarExtra.Item
                title="Mark All as Read"
                icon={Icon.CheckCircle}
                shortcut={{ modifiers: ["cmd", "shift"], key: "r" }}
                onAction={handleMarkAllRead}
              />
            )}
            <MenuBarExtra.Item
              title="Open Connections"
              icon={Icon.AppWindow}
              shortcut={{ modifiers: ["cmd"], key: "o" }}
              onAction={() =>
                launchCommand({ name: "connections", type: LaunchType.UserInitiated })
              }
            />
            <MenuBarExtra.Item
              title="Refresh"
              icon={Icon.ArrowClockwise}
              shortcut={{ modifiers: ["cmd"], key: "r" }}
              onAction={() => revalidate()}
            />
          </MenuBarExtra.Section>
        </>
      )}
    </MenuBarExtra>
  );
}
