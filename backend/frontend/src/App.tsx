import { useCallback, useEffect, useState, type FormEvent } from "react";
import { ApiError, errorMessage, request } from "./api";
import { Keys } from "./Keys";
import { Scripts } from "./Scripts";
import { Settings, ThemeSelect } from "./Settings";
import { useTheme } from "./useTheme";
import type { ThemePreference } from "./theme";
import { Brand, Icon, useTask } from "./ui";
import type { Api, Application, Notify } from "./types";

export function App() {
  const { theme, chooseTheme } = useTheme();
  const [session, setSession] = useState<string | null | undefined>(undefined);
  const [loginError, setLoginError] = useState("");
  const [loginRetryAt, setLoginRetryAt] = useState(0);
  const [toast, setToast] = useState<{
    message: string;
    error: boolean;
    id: number;
  } | null>(null);
  const notify = useCallback<Notify>(
    (message, error = false) => setToast({ message, error, id: Date.now() }),
    [],
  );
  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 5000);
    return () => clearTimeout(timer);
  }, [toast]);
  useEffect(() => {
    const controller = new AbortController();
    request<{ csrf: string }>("/me", "", undefined, controller.signal)
      .then((data) => setSession(data.csrf))
      .catch((error) => {
        if (controller.signal.aborted) return;
        setSession(null);
        if (!(
          error instanceof ApiError && error.code === "admin_login_required"
        ))
          setLoginError(errorMessage(error));
      });
    return () => controller.abort();
  }, []);
  const api: Api = useCallback(
    async <T,>(path: string, body?: unknown, signal?: AbortSignal) => {
      try {
        return await request<T>(path, session || "", body, signal);
      } catch (error) {
        if (
          error instanceof ApiError &&
          error.code === "admin_login_required"
        ) {
          setSession(null);
          setLoginError(error.message);
          setToast(null);
        }
        throw error;
      }
    },
    [session],
  );

  return (
    <>
      {session === undefined ? (
        <div className="boot">
          <Brand />
          <p>Opening workspace…</p>
        </div>
      ) : session ? (
        <Workspace
          api={api}
          notify={notify}
          theme={theme}
          onTheme={chooseTheme}
          onLogout={() => {
            setSession(null);
            setToast(null);
            setLoginError("");
          }}
        />
      ) : (
        <Login
          error={loginError}
          retryAt={loginRetryAt}
          theme={theme}
          onTheme={chooseTheme}
          onLogin={async (password) => {
            setLoginError("");
            setLoginRetryAt(0);
            try {
              const data = await request<{ csrf: string }>("/login", "", {
                password,
              });
              setSession(data.csrf);
            } catch (error) {
              setLoginError(errorMessage(error));
              if (error instanceof ApiError && error.retryAfter)
                setLoginRetryAt(Date.now() + error.retryAfter * 1000);
            }
          }}
        />
      )}
      {toast ? (
        <div
          id="toast"
          className={`toast ${toast.error ? "error-toast" : ""}`}
          role={toast.error ? "alert" : "status"}
        >
          <Icon name={toast.error ? "close" : "check"} />
          <span>{toast.message}</span>
          <button
            aria-label="Dismiss notification"
            onClick={() => setToast(null)}
          >
            <Icon name="close" />
          </button>
        </div>
      ) : null}
    </>
  );
}

function Login({
  error,
  retryAt,
  theme,
  onTheme,
  onLogin,
}: {
  error: string;
  retryAt: number;
  theme: ThemePreference;
  onTheme: (theme: ThemePreference) => void;
  onLogin: (password: string) => Promise<void>;
}) {
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [now, setNow] = useState(Date.now);
  const cooldown = Math.max(0, Math.ceil((retryAt - now) / 1000));
  useEffect(() => {
    if (!retryAt) return;
    setNow(Date.now());
    const timer = setInterval(() => {
      const current = Date.now();
      setNow(current);
      if (current >= retryAt) clearInterval(timer);
    }, 1000);
    return () => clearInterval(timer);
  }, [retryAt]);
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (busy || cooldown > 0) return;
    setBusy(true);
    try {
      await onLogin(password);
    } finally {
      setBusy(false);
      setPassword("");
    }
  }
  return (
    <main className="login" id="login-view">
      <header className="login-header">
        <Brand />
        <ThemeSelect theme={theme} onTheme={onTheme} />
      </header>
      <div className="login-main">
        <div className="login-intro">
          <span className="login-symbol">
            <Icon name="lock" />
          </span>
          <h1>Welcome back.</h1>
          <p>Sign in to your Kinoue workspace.</p>
        </div>
        <form
          id="login-form"
          onSubmit={submit}
          className="login-form"
          aria-busy={busy}
        >
          <label htmlFor="password">Admin password</label>
          <input
            id="password"
            type="password"
            required
            autoFocus
            autoComplete="current-password"
            maxLength={256}
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            disabled={busy}
            aria-describedby={error ? "login-error" : undefined}
          />
          {error ? (
            <p id="login-error" role="alert" className="form-error">
              {error}
            </p>
          ) : null}
          <button className="button primary" disabled={busy || cooldown > 0}>
            {busy
              ? "Signing in…"
              : cooldown > 0
                ? `Try again in ${Math.floor(cooldown / 60)}:${String(cooldown % 60).padStart(2, "0")}`
                : "Sign in"}
            <Icon name="arrow" />
          </button>
        </form>
        <p className="login-note">Private workspace · Administrator access</p>
      </div>
      <footer className="login-footer">
        <span>Kinoue Library</span>
        <span>Script access, in one place.</span>
      </footer>
    </main>
  );
}

function Workspace({
  api,
  notify,
  onLogout,
  theme,
  onTheme,
}: {
  api: Api;
  notify: Notify;
  onLogout: () => void;
  theme: ThemePreference;
  onTheme: (theme: ThemePreference) => void;
}) {
  const [view, setView] = useState<"keys" | "scripts" | "settings">("keys");
  const [applications, setApplications] = useState<Application[]>([]);
  const [error, setError] = useState("");
  const [refresh, setRefresh] = useState(0);
  const [loaded, setLoaded] = useState(false);
  const { busy, run } = useTask(notify);
  useEffect(() => {
    const controller = new AbortController();
    api<{ items: Application[] }>("/applications", undefined, controller.signal)
      .then((data) => {
        setApplications(data.items);
        setError("");
        setLoaded(true);
      })
      .catch((error) => {
        if (!controller.signal.aborted) {
          setError(errorMessage(error));
          setLoaded(true);
        }
      });
    return () => controller.abort();
  }, [api, refresh]);
  return (
    <div className="workspace" id="dashboard">
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <aside className="sidebar">
        <div className="sidebar-top">
          <Brand />
          <div className="workspace-label">
            <div>
              <strong>King</strong>
              <small>Workspace</small>
            </div>
            <span className="workspace-indicator" title="Connected workspace" />
          </div>
          <div className="nav-label">Manage</div>
          <nav aria-label="Workspace">
            <button
              className={view === "keys" ? "nav-item selected" : "nav-item"}
              aria-current={view === "keys" ? "page" : undefined}
              onClick={() => setView("keys")}
            >
              <Icon name="key" />
              Access keys
            </button>
            <button
              id="open-scripts"
              className={view === "scripts" ? "nav-item selected" : "nav-item"}
              aria-current={view === "scripts" ? "page" : undefined}
              onClick={() => setView("scripts")}
            >
              <Icon name="code" />
              Scripts<span className="nav-count">{applications.length}</span>
            </button>
            <button
              id="open-settings"
              className={view === "settings" ? "nav-item selected" : "nav-item"}
              aria-current={view === "settings" ? "page" : undefined}
              onClick={() => setView("settings")}
            >
              <Icon name="settings" />
              Settings
            </button>
          </nav>
        </div>
        <div className="sidebar-bottom">
          <div className="sidebar-caption">
            Kinoue Library<span>Access management</span>
          </div>
          <button
            id="logout"
            className="nav-item logout"
            disabled={busy}
            onClick={() =>
              run(async () => {
                await api("/logout", {});
                onLogout();
              })
            }
          >
            <Icon name="logout" />
            {busy ? "Signing out…" : "Sign out"}
          </button>
        </div>
      </aside>
      <div className="workspace-content">
        <header className="topbar">
          <div className="breadcrumb">
            <span>King</span>
            <span className="slash">/</span>
            <strong>
              {
                {
                  keys: "Access keys",
                  scripts: "Scripts",
                  settings: "Settings",
                }[view]
              }
            </strong>
          </div>
          <span className="admin-label">
            <Icon name="lock" />
            Administrator
          </span>
        </header>
        <main id="main" tabIndex={-1}>
          {error ? (
            <div role="alert" className="error-banner">
              {error}
              <button
                className="text-button"
                onClick={() => setRefresh((value) => value + 1)}
              >
                Retry
              </button>
            </div>
          ) : null}
          {view === "keys" ? (
            <Keys
              api={api}
              notify={notify}
              applications={applications}
              applicationsLoaded={loaded}
              onScripts={() => setView("scripts")}
            />
          ) : view === "scripts" ? (
            <Scripts
              api={api}
              notify={notify}
              applications={applications}
              loaded={loaded}
              onSaved={() => setRefresh((value) => value + 1)}
            />
          ) : (
            <Settings theme={theme} onTheme={onTheme} />
          )}
        </main>
        <footer className="workspace-footer">
          <span>Kinoue / King</span>
          <span>Private admin workspace</span>
        </footer>
      </div>
    </div>
  );
}
