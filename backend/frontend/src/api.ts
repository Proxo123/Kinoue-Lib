const messages: Record<string, string> = {
  invalid_admin_password: "Incorrect password. Try again.",
  admin_login_required: "Your session ended. Sign in again.",
  admin_unconfigured: "The admin password is not configured.",
  admin_origin_unconfigured: "The admin site address is not configured.",
  invalid_origin: "This site address is not allowed.",
  invalid_csrf: "Refresh the page and try again.",
  invalid_request: "Check the entered values.",
  request_too_large: "This file is too large.",
  rate_limited: "Too many requests. Try again shortly.",
  not_found: "This key no longer exists.",
};

export class ApiError extends Error {
  constructor(
    public code: string,
    public retryAfter: number | null = null,
  ) {
    super(messages[code] || "The request failed. Try again.");
  }
}

export async function request<T>(
  path: string,
  csrf: string,
  body?: unknown,
  signal?: AbortSignal,
): Promise<T> {
  let response: Response;
  try {
    response = await fetch("/admin/api" + path, {
      method: body === undefined ? "GET" : "POST",
      credentials: "same-origin",
      cache: "no-store",
      signal,
      headers:
        body === undefined
          ? {}
          : { "Content-Type": "application/json", "X-CSRF-Token": csrf },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (error) {
    if (signal?.aborted) throw error;
    throw new Error("Could not connect. Check your connection and try again.");
  }
  let data;
  try {
    data = await response.json();
  } catch {
    throw new Error("The server returned an unreadable response.");
  }
  if (!response.ok) {
    const rawRetry = Number(response.headers.get("Retry-After"));
    const retryAfter =
      response.status === 429 && Number.isFinite(rawRetry) && rawRetry > 0
        ? Math.min(rawRetry, 86400)
        : null;
    throw new ApiError(data.error || "request_failed", retryAfter);
  }
  return data as T;
}

export function errorMessage(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "Something went wrong. Try again.";
}

export function date(value: number | null, time = false): string {
  return value
    ? new Date(value * 1000).toLocaleString(
        undefined,
        time
          ? { dateStyle: "medium", timeStyle: "medium" }
          : { dateStyle: "medium" },
      )
    : "Never";
}

export function remaining(expires: number | null): string {
  if (expires === null) return "No expiry";
  const days = Math.ceil((expires * 1000 - Date.now()) / 86400000);
  return days > 1
    ? `${days} days left`
    : days === 1
      ? "Less than a day left"
      : "Expired";
}
