import TurndownService from "turndown";

const turndown = new TurndownService({
  headingStyle: "atx",
  codeBlockStyle: "fenced",
});

// Remove script, style, nav, footer, header elements
turndown.remove(["script", "style", "nav", "footer", "header", "aside", "iframe", "noscript"]);

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

export async function fetchArticleContent(url: string): Promise<ArticleContentResult> {
  try {
    const response = await fetch(url);

    if (!response.ok) {
      return { error: `Failed to fetch article: ${response.status} ${response.statusText}` };
    }

    const html = await response.text();

    // Try to extract main content area
    const mainContent = extractMainContent(html);
    const markdown = turndown.turndown(mainContent);

    return { markdown };
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return { error: `Failed to fetch article: ${message}` };
  }
}

function extractMainContent(html: string): string {
  // Try to find article or main content by looking for common patterns
  // This is a simple heuristic - not as sophisticated as Readability

  // Look for <article> tag
  const articleMatch = html.match(/<article[^>]*>([\s\S]*?)<\/article>/i);
  if (articleMatch) {
    return articleMatch[0];
  }

  // Look for main tag
  const mainMatch = html.match(/<main[^>]*>([\s\S]*?)<\/main>/i);
  if (mainMatch) {
    return mainMatch[0];
  }

  // Look for common content class names
  const contentPatterns = [
    /<div[^>]*class="[^"]*(?:post-content|article-content|entry-content|content-body|story-body)[^"]*"[^>]*>([\s\S]*?)<\/div>/i,
    /<div[^>]*id="[^"]*(?:content|article|post|main)[^"]*"[^>]*>([\s\S]*?)<\/div>/i,
  ];

  for (const pattern of contentPatterns) {
    const match = html.match(pattern);
    if (match) {
      return match[0];
    }
  }

  // Look for body content as fallback
  const bodyMatch = html.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
  if (bodyMatch) {
    return bodyMatch[0];
  }

  return html;
}
