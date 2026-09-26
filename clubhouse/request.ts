export function leagueFetch(input: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  const token = document.querySelector<HTMLMetaElement>(
    'meta[name="csrf-token"]',
  )?.content;
  if (token) headers.set("X-CSRF-Token", token);
  return fetch(input, { ...init, headers, credentials: "same-origin" });
}
