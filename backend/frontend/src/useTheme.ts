import { useEffect, useState } from "react";
import {
  applyTheme,
  readTheme,
  THEME_KEY,
  validTheme,
  type ThemePreference,
} from "./theme";

export function useTheme() {
  const [theme, setTheme] = useState<ThemePreference>(readTheme);
  useEffect(() => {
    applyTheme(theme);
    const media = matchMedia("(prefers-color-scheme: dark)");
    const systemChanged = () => {
      if (theme === "system") applyTheme(theme);
    };
    const savedChanged = (event: StorageEvent) => {
      if (event.key === THEME_KEY || event.key === null)
        setTheme(validTheme(event.key === null ? null : event.newValue));
    };
    media.addEventListener("change", systemChanged);
    window.addEventListener("storage", savedChanged);
    return () => {
      media.removeEventListener("change", systemChanged);
      window.removeEventListener("storage", savedChanged);
    };
  }, [theme]);
  function chooseTheme(value: ThemePreference) {
    setTheme(value);
    applyTheme(value);
    try {
      localStorage.setItem(THEME_KEY, value);
    } catch {
      /* The current tab still works when storage is unavailable. */
    }
  }
  return { theme, chooseTheme };
}
