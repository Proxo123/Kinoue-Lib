export type ThemePreference = "light" | "dark" | "system";
export const THEME_KEY = "kinoue.appearance.v1";

export function validTheme(value: string | null): ThemePreference {
  return value === "light" || value === "dark" ? value : "system";
}

export function readTheme(): ThemePreference {
  try {
    return validTheme(localStorage.getItem(THEME_KEY));
  } catch {
    return "system";
  }
}

export function applyTheme(preference: ThemePreference) {
  const dark =
    preference === "dark" ||
    (preference === "system" &&
      matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.dataset.theme = dark ? "dark" : "light";
  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute("content", dark ? "#191d1a" : "#f7f7f5");
}
