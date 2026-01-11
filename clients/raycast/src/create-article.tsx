import { Action, ActionPanel, Form, Icon, popToRoot, showToast, Toast, useNavigation } from "@raycast/api";
import { useState } from "react";
import { getServerUrl } from "./api/config";
import * as Article from "./api/article";

export default function Command() {
  const { push } = useNavigation();
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(values: { url: string }) {
    const url = values.url.trim();
    if (!url) {
      showToast({
        style: Toast.Style.Failure,
        title: "Missing URL",
        message: "Please paste a URL",
      });
      return;
    }

    setIsLoading(true);
    try {
      const intake = await Article.fetchArticleIntake(url);
      push(<ArticlePreviewForm intake={intake} />);
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to fetch URL",
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
          <Action.SubmitForm title="Fetch URL" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField id="url" title="URL" placeholder="https://example.com/article" autoFocus />
      <Form.Description text="Paste an article URL to add it to your collection. If the author isn't in your connections, you can create them too." />
    </Form>
  );
}

async function createPerson(
  name: string,
  websiteUrl?: string,
  feeds?: Array<{ url: string; title: string | null }>,
  profiles?: Array<Article.SocialProfile>,
): Promise<Article.ExistingPerson> {
  const response = await fetch(`${getServerUrl()}/persons`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name, url: websiteUrl }),
  });
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to create person");
  }
  const person = await response.json();

  // Create feeds if provided
  if (feeds && feeds.length > 0) {
    for (const feed of feeds) {
      await fetch(`${getServerUrl()}/persons/${person.id}/feeds`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          person_id: person.id,
          url: feed.url,
          title: feed.title,
        }),
      });
    }
  }

  // Create metadata entries for profiles if provided
  if (profiles && profiles.length > 0) {
    for (const profile of profiles) {
      await fetch(`${getServerUrl()}/persons/${person.id}/metadata`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          field_type_id: profile.field_type.id,
          value: profile.url,
        }),
      });
    }
  }

  return person;
}

interface ArticlePreviewFormProps {
  intake: Article.ArticleIntakeResponse;
}

function ArticlePreviewForm({ intake }: ArticlePreviewFormProps) {
  const [isCreating, setIsCreating] = useState(false);

  // Determine if we have an existing person or need to create one
  const hasExistingPerson = intake.person !== null;
  const proposedPerson = intake.proposed_person;

  // Suggested name for new person - prefer article author, then proposed person name, then hostname
  const suggestedPersonName = intake.article.author_name || proposedPerson?.name || new URL(intake.url).hostname;

  async function handleSubmit(values: Record<string, unknown>) {
    setIsCreating(true);
    try {
      let personId: number | undefined;

      // If no existing person, create one if name is provided
      if (!hasExistingPerson) {
        const personName = values.person_name as string;
        if (personName && personName.trim()) {
          // Collect selected feeds
          const feedsToCreate = proposedPerson?.feeds.filter((f) => values[`feed_${f.url}`] === true) ?? [];
          // Collect selected profiles
          const profilesToCreate =
            proposedPerson?.social_profiles.filter((p) => values[`profile_${p.url}`] === true) ?? [];

          // Extract domain root URL for Website metadata
          const articleUrl = new URL(intake.url);
          const websiteUrl = `${articleUrl.protocol}//${articleUrl.hostname}`;

          const newPerson = await createPerson(
            personName.trim(),
            websiteUrl,
            feedsToCreate.map((f) => ({ url: f.url, title: f.title || null })),
            profilesToCreate,
          );
          personId = newPerson.id;
        }
      } else {
        personId = intake.person!.id;
      }

      // Create the article
      const articleInput: Article.CreateArticleInput = {
        url: intake.url,
        person_id: personId,
        title: (values.title as string) || intake.article.title,
        author: intake.article.author_name,
        image_url: intake.article.image,
        published_at: intake.article.published_at,
      };

      await Article.createArticle(articleInput);

      const parts: string[] = [];
      if (!hasExistingPerson && personId) {
        parts.push("person created");
      }

      showToast({
        style: Toast.Style.Success,
        title: "Article created",
        message: parts.length > 0 ? parts.join(", ") : undefined,
      });
      popToRoot();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to create article",
        message: error instanceof Error ? error.message : "Unknown error",
      });
    } finally {
      setIsCreating(false);
    }
  }

  return (
    <Form
      isLoading={isCreating}
      navigationTitle="Create Article"
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Create Article" icon={Icon.Plus} onSubmit={handleSubmit} />
          <Action.OpenInBrowser title="Open URL" url={intake.url} />
        </ActionPanel>
      }
    >
      {/* Source URL */}
      <Form.Description title="Source" text={intake.url} />

      {/* Article Section */}
      <Form.Separator />
      <Form.TextField id="title" title="Title" defaultValue={intake.article.title || ""} placeholder="Article title" />
      {intake.article.description && <Form.Description title="Description" text={intake.article.description} />}
      {intake.article.author_name && <Form.Description title="Author" text={intake.article.author_name} />}
      {intake.article.site_name && <Form.Description title="Site" text={intake.article.site_name} />}

      {/* Person Section */}
      <Form.Separator />
      {hasExistingPerson ? (
        <Form.Description title="Person" text={`✓ Matched: ${intake.person!.name}`} />
      ) : (
        <>
          <Form.TextField
            id="person_name"
            title="Person Name"
            defaultValue={suggestedPersonName}
            placeholder="Enter person's name (optional)"
            info="Leave empty to create article without a person"
          />
          {proposedPerson?.bio && <Form.Description text={proposedPerson.bio} />}

          {/* Feeds Section */}
          {proposedPerson && proposedPerson.feeds.length > 0 && (
            <>
              <Form.Separator />
              {proposedPerson.feeds.map((feed, index) => (
                <Form.Checkbox
                  key={feed.url}
                  id={`feed_${feed.url}`}
                  title={index === 0 ? "Feeds" : ""}
                  label={`${feed.title || "Untitled"} (${feed.format})`}
                  defaultValue={true}
                  info={feed.url}
                />
              ))}
            </>
          )}

          {/* Social Profiles Section */}
          {proposedPerson && proposedPerson.social_profiles.length > 0 && (
            <>
              <Form.Separator />
              {proposedPerson.social_profiles.map((profile, index) => (
                <Form.Checkbox
                  key={profile.url}
                  id={`profile_${profile.url}`}
                  title={index === 0 ? "Profiles" : ""}
                  label={`${profile.field_type.name}: ${profile.url}`}
                  defaultValue={true}
                />
              ))}
            </>
          )}
        </>
      )}
    </Form>
  );
}
