export interface Feed {
  url: string;
  title: string | null;
  format: "rss" | "atom" | "json_feed";
}

export interface MetadataFieldType {
  id: number;
  name: string;
}

export interface ClassifiedProfile {
  url: string;
  field_type: MetadataFieldType;
}

export interface Author {
  name: string | null;
  url: string | null;
  email: string | null;
  photo: string | null;
  bio: string | null;
  location: string | null;
  social_profiles: string[];
  classified_profiles: ClassifiedProfile[];
}

export interface Content {
  title: string | null;
  description: string | null;
  published_at: string | null;
  modified_at: string | null;
  author: Author | null;
  image: string | null;
  tags: string[];
  content_type: string | null;
}

export interface Site {
  name: string | null;
  canonical_url: string | null;
  favicon: string | null;
  locale: string | null;
  webmention_endpoint: string | null;
}

export interface MergedMetadata {
  url: string;
  feeds: Feed[];
  author: Author | null;
  content: Content;
  site: Site;
  raw_json_ld: unknown[];
}

export interface MetadataResponse {
  merged: MergedMetadata;
  sources: {
    html_meta: {
      title: string | null;
      description: string | null;
      author: string | null;
      canonical: string | null;
      favicon: string | null;
      webmention: string | null;
    };
    opengraph: {
      title: string | null;
      og_type: string | null;
      url: string | null;
      image: string | null;
      description: string | null;
      site_name: string | null;
      locale: string | null;
      author: string | null;
      published_time: string | null;
      modified_time: string | null;
      tags: string[];
    };
    twitter: {
      card_type: string | null;
      site: string | null;
      creator: string | null;
      title: string | null;
      description: string | null;
      image: string | null;
    };
    json_ld: {
      persons: Array<{
        name: string | null;
        url: string | null;
        image: string | null;
        email: string | null;
        job_title: string | null;
        same_as: string[];
      }>;
      articles: Array<{
        headline: string | null;
        author: {
          name: string | null;
          url: string | null;
        } | null;
        date_published: string | null;
        date_modified: string | null;
        description: string | null;
        image: string | null;
      }>;
      raw: unknown[];
    };
    microformats: {
      cards: Array<{
        name: string | null;
        url: string | null;
        photo: string | null;
        email: string | null;
        note: string | null;
        locality: string | null;
        country: string | null;
      }>;
      entries: Array<{
        name: string | null;
        summary: string | null;
        published: string | null;
        updated: string | null;
        author: {
          name: string | null;
          url: string | null;
        } | null;
        categories: string[];
      }>;
      rel_me: string[];
    };
  };
}

export async function fetchMetadata(url: string): Promise<MetadataResponse> {
  const params = new URLSearchParams({ url });
  const response = await fetch(`http://localhost:8080/url-metadata?${params.toString()}`);
  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || "Failed to fetch metadata");
  }
  return response.json();
}
