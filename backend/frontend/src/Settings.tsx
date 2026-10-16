import type { ThemePreference } from "./theme";

export function Settings({
  theme,
  onTheme,
}: {
  theme: ThemePreference;
  onTheme: (theme: ThemePreference) => void;
}) {
  return (
    <>
      <div className="page-heading">
        <div>
          <h1>Settings</h1>
          <p>Make this workspace feel right for you.</p>
        </div>
      </div>
      <section
        className="table-panel settings-panel"
        aria-labelledby="appearance-heading"
      >
        <div className="panel-heading">
          <h2 id="appearance-heading">Appearance</h2>
        </div>
        <div className="settings-body">
          <p>Choose a color theme. System follows your device’s appearance.</p>
          <fieldset className="theme-options">
            <legend className="sr-only">Color theme</legend>
            {(["light", "dark", "system"] as const).map((value) => (
              <label
                className={`theme-option ${theme === value ? "chosen" : ""}`}
                key={value}
              >
                <span
                  className={`theme-preview preview-${value}`}
                  aria-hidden="true"
                >
                  <span className="preview-sidebar" />
                  <span className="preview-content">
                    <span />
                    <span />
                    <span />
                  </span>
                </span>
                <span className="theme-option-label">
                  <span>{value[0].toUpperCase() + value.slice(1)}</span>
                  <input
                    type="radio"
                    name="theme"
                    value={value}
                    checked={theme === value}
                    onChange={() => onTheme(value)}
                  />
                </span>
              </label>
            ))}
          </fieldset>
          <p className="field-note">
            Saved in this browser and applied to the sign-in screen, too.
          </p>
        </div>
      </section>
    </>
  );
}

export function ThemeSelect({
  theme,
  onTheme,
}: {
  theme: ThemePreference;
  onTheme: (theme: ThemePreference) => void;
}) {
  return (
    <select
      className="theme-select"
      aria-label="Color theme"
      value={theme}
      onChange={(event) => onTheme(event.target.value as ThemePreference)}
    >
      <option value="system">System theme</option>
      <option value="light">Light theme</option>
      <option value="dark">Dark theme</option>
    </select>
  );
}
