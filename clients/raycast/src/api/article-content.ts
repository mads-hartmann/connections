import { getServerUrl } from "./config";

export interface ArticleContent {
  markdown: string;
}

export interface ArticleContentError {
  error: string;
}

export type ArticleContentResult = ArticleContent | ArticleContentError;

export function isArticleContentError(result: ArticleContentResult): result is ArticleContentError {
  return "error" in result;
}

export async function fetchArticleContent(articleId: number): Promise<ArticleContentResult> {
  try {
    const response = await fetch(`${getServerUrl()}/articles/${articleId}/content`);

    if (!response.ok) {
      const data = await response.json().catch(() => ({}));
      const errorMessage = data.error || `${response.status} ${response.statusText}`;
      return { error: errorMessage };
    }

    const data = await response.json();
    return { markdown: data.markdown };
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return { error: `Failed to fetch article content: ${message}` };
  }
}
