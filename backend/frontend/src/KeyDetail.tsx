import { useEffect, useRef, useState, type FormEvent } from "react";
import { date, errorMessage, remaining } from "./api";
import { Badge, copy, Dialog, Empty, Icon, Pager, useTask } from "./ui";
import type { Action, Api, Detail, Execution, Notify, Page } from "./types";

const actions: Record<string, string> = {
  key_created: "Key created",
  key_revoked: "Key revoked",
  hwid_reset: "Device binding reset",
  set_hwid: "Device binding replaced",
  renew: "Access renewed",
  restore: "Key restored",
  delete: "Key deleted",
};
const tabs = ["Overview", "Executions", "Activity"] as const;
type Tab = (typeof tabs)[number];

export function KeyDetail({
  id,
  api,
  notify,
  scriptName,
  onClose,
  onChanged,
}: {
  id: string;
  api: Api;
  notify: Notify;
  scriptName: (id: string) => string;
  onClose: () => void;
  onChanged: () => void;
}) {
  const [detail, setDetail] = useState<Detail | null>(null);
  const [tab, setTab] = useState<Tab>("Overview");
  const [error, setError] = useState("");
  const [retry, setRetry] = useState(0);
  const [deleteConfirm, setDeleteConfirm] = useState(false);
  const { busy, run } = useTask(notify);
  useEffect(() => {
    const controller = new AbortController();
    api<Detail>(
      `/licenses/${encodeURIComponent(id)}`,
      undefined,
      controller.signal,
    )
      .then((data) => {
        setDetail(data);
        setError("");
      })
      .catch((error) => {
        if (!controller.signal.aborted) setError(errorMessage(error));
      });
    return () => controller.abort();
  }, [api, id, retry]);
  function change(action: Action, value: string | number | null = null) {
    run(async () => {
      await api(`/licenses/${encodeURIComponent(id)}`, { action, value });
      onChanged();
      if (action === "delete") {
        onClose();
        notify("Key deleted.");
        return;
      }
      setDetail(await api<Detail>(`/licenses/${encodeURIComponent(id)}`));
      notify(
        {
          revoke: "Key revoked.",
          restore: "Key restored.",
          "reset-hwid": "Device binding reset.",
          "set-hwid": "Device binding replaced.",
          renew: "Access renewed.",
        }[action],
      );
    });
  }
  return (
    <Dialog
      id="detail-dialog"
      title={detail?.label || detail?.key_hint || "Key details"}
      subtitle={
        detail
          ? `${scriptName(detail.application)} · ${detail.key_hint || detail.id.slice(0, 12)}`
          : "Loading key…"
      }
      onClose={onClose}
      busy={busy}
      drawer
    >
      {error ? (
        <div className="error-banner" role="alert">
          {error}
          <button
            className="text-button"
            onClick={() => setRetry((value) => value + 1)}
          >
            Retry
          </button>
        </div>
      ) : null}
      {detail ? (
        <>
          <div className="detail-summary">
            <Badge status={detail.status} />
            <span>
              <span id="detail-expiry">{remaining(detail.expires_at)}</span>
              <span className="summary-separator">·</span>Expires{" "}
              {date(detail.expires_at)}
            </span>
          </div>
          <div className="detail-tabs" role="tablist" aria-label="Key details">
            {tabs.map((name, index) => (
              <button
                key={name}
                role="tab"
                id={`tab-${name.toLowerCase()}`}
                aria-selected={tab === name}
                aria-controls="detail-panel"
                tabIndex={tab === name ? 0 : -1}
                onClick={() => setTab(name)}
                onKeyDown={(event) => {
                  const next =
                    event.key === "ArrowRight"
                      ? (index + 1) % tabs.length
                      : event.key === "ArrowLeft"
                        ? (index + tabs.length - 1) % tabs.length
                        : event.key === "Home"
                          ? 0
                          : event.key === "End"
                            ? tabs.length - 1
                            : -1;
                  if (next >= 0) {
                    event.preventDefault();
                    setTab(tabs[next]);
                    document
                      .getElementById(`tab-${tabs[next].toLowerCase()}`)
                      ?.focus();
                  }
                }}
              >
                {name}
                {name === "Executions" ? (
                  <span className="count-tag">{detail.executions.total}</span>
                ) : null}
              </button>
            ))}
          </div>
          <div
            id="detail-panel"
            role="tabpanel"
            aria-labelledby={`tab-${tab.toLowerCase()}`}
            tabIndex={0}
            className="drawer-content"
          >
            {tab === "Overview" ? (
              <>
                <section className="detail-section">
                  <div className="section-heading">
                    <h3>Key information</h3>
                    <span className="muted">
                      {scriptName(detail.application)}
                    </span>
                  </div>
                  <dl className="facts">
                    <div>
                      <dt>Created</dt>
                      <dd>{date(detail.created_at, true)}</dd>
                    </div>
                    <div>
                      <dt>Last seen</dt>
                      <dd>{date(detail.last_seen, true)}</dd>
                    </div>
                    <div>
                      <dt>License ID</dt>
                      <dd className="mono license-id">{detail.id}</dd>
                    </div>
                  </dl>
                </section>
                <fieldset disabled={busy}>
                  <section className="detail-section">
                    <div className="section-heading">
                      <h3>Device binding</h3>
                      <span className="muted">
                        {detail.hwid_bound
                          ? "Bound to one device"
                          : "No device bound"}
                      </span>
                    </div>
                    <label htmlFor="bound-hwid" className="sr-only">
                      Bound HWID
                    </label>
                    <div className="hwid-value">
                      <textarea
                        id="bound-hwid"
                        readOnly
                        className="mono"
                        value={
                          detail.hwid ||
                          (detail.hwid_bound
                            ? `Fingerprint: ${detail.hwid_fingerprint}`
                            : "Unbound")
                        }
                      />
                      <button
                        id="copy-hwid"
                        className="icon-button"
                        type="button"
                        aria-label="Copy HWID"
                        disabled={!detail.hwid}
                        onClick={() => copy(detail.hwid!, notify)}
                      >
                        <Icon name="copy" />
                      </button>
                    </div>
                    <div className="binding-actions">
                      <p className="field-note">
                        Reset to let the next redemption bind a new device.
                      </p>
                      <button
                        id="reset-hwid"
                        className="button secondary small"
                        type="button"
                        disabled={!detail.hwid_bound}
                        onClick={() => change("reset-hwid")}
                      >
                        Reset binding
                      </button>
                    </div>
                    <details className="replace-binding">
                      <summary>Set a specific HWID</summary>
                      <form
                        id="hwid-form"
                        onSubmit={(event: FormEvent<HTMLFormElement>) => {
                          event.preventDefault();
                          change(
                            "set-hwid",
                            String(
                              new FormData(event.currentTarget).get("hwid"),
                            ),
                          );
                          event.currentTarget.reset();
                        }}
                      >
                        <label htmlFor="replacement-hwid">
                          Replacement HWID
                        </label>
                        <div className="inline-form">
                          <input
                            id="replacement-hwid"
                            name="hwid"
                            required
                            maxLength={512}
                            placeholder="Paste a device HWID"
                          />
                          <button className="button secondary">Replace</button>
                        </div>
                      </form>
                    </details>
                  </section>
                  <section className="detail-section">
                    <div className="section-heading">
                      <h3>Access duration</h3>
                    </div>
                    <form
                      id="renew-form"
                      className="renew-form"
                      onSubmit={(event) => {
                        event.preventDefault();
                        change(
                          "renew",
                          Number(new FormData(event.currentTarget).get("days")),
                        );
                      }}
                    >
                      <div>
                        <label htmlFor="renew-days">New duration</label>
                        <div className="input-suffix">
                          <input
                            id="renew-days"
                            name="days"
                            type="number"
                            defaultValue={30}
                            min={1}
                            max={3650}
                            required
                          />
                          <span>days</span>
                        </div>
                      </div>
                      <button className="button secondary">Renew key</button>
                    </form>
                    <p className="field-note">
                      Sets a new expiry date, starting from today.
                    </p>
                  </section>
                  <section className="detail-section access-actions">
                    <div>
                      <h3>
                        {detail.status === "revoked"
                          ? "Restore access"
                          : "Suspend access"}
                      </h3>
                      <p className="field-note">
                        {detail.status === "revoked"
                          ? "Allow this key to be used again."
                          : "Revoke this key to prevent future use."}
                      </p>
                    </div>
                    <button
                      id="revoke-key"
                      className="button secondary small"
                      onClick={() =>
                        change(
                          detail.status === "revoked" ? "restore" : "revoke",
                        )
                      }
                    >
                      {detail.status === "revoked"
                        ? "Restore key"
                        : "Revoke key"}
                    </button>
                  </section>
                  <section className="detail-section delete-section">
                    {deleteConfirm ? (
                      <div className="delete-confirm" role="alert">
                        <h3>Delete this key permanently?</h3>
                        <p>Its execution history will also be removed.</p>
                        <div>
                          <button
                            className="button secondary small"
                            onClick={() => setDeleteConfirm(false)}
                          >
                            Keep key
                          </button>
                          <button
                            className="button danger small"
                            id="confirm-delete"
                            onClick={() => change("delete")}
                          >
                            Delete permanently
                          </button>
                        </div>
                      </div>
                    ) : (
                      <button
                        id="delete-key"
                        className="text-button danger-text"
                        onClick={() => setDeleteConfirm(true)}
                      >
                        Delete key…
                      </button>
                    )}
                  </section>
                </fieldset>
              </>
            ) : tab === "Executions" ? (
              <Executions
                api={api}
                notify={notify}
                id={id}
                initial={detail.executions}
              />
            ) : (
              <section className="detail-section">
                <div className="section-heading">
                  <h3>Admin activity</h3>
                  <span className="muted">Latest 20 events</span>
                </div>
                <ol className="activity-list" id="activity-list">
                  {detail.activity.map((event, index) => (
                    <li key={`${event.created_at}-${index}`}>
                      <span className="activity-dot" />
                      <div>
                        <strong>{actions[event.action] || event.action}</strong>
                        <time
                          dateTime={new Date(
                            event.created_at * 1000,
                          ).toISOString()}
                        >
                          {date(event.created_at, true)}
                        </time>
                      </div>
                    </li>
                  ))}
                </ol>
              </section>
            )}
          </div>
        </>
      ) : !error ? (
        <p className="dialog-body muted" role="status">
          Loading key details…
        </p>
      ) : null}
    </Dialog>
  );
}

function Executions({
  api,
  notify,
  id,
  initial,
}: {
  api: Api;
  notify: Notify;
  id: string;
  initial: Page<Execution>;
}) {
  const [data, setData] = useState(initial);
  const controller = useRef<AbortController | null>(null);
  const { busy, run } = useTask(notify);
  useEffect(() => () => controller.current?.abort(), []);
  function load(page: number) {
    run(async () => {
      controller.current?.abort();
      const current = new AbortController();
      controller.current = current;
      try {
        const result = await api<Page<Execution>>(
          `/licenses/${encodeURIComponent(id)}/executions?page=${page}`,
          undefined,
          current.signal,
        );
        if (!current.signal.aborted) setData(result);
      } catch (error) {
        if (!current.signal.aborted) throw error;
      }
    });
  }
  return (
    <section className="execution-section" aria-busy={busy}>
      <div className="execution-heading">
        <div>
          <h3 id="executions-title">Player executions</h3>
          <p>Players who started the script with this key.</p>
        </div>
        <button
          id="refresh-executions"
          className="icon-button"
          aria-label="Refresh executions"
          disabled={busy}
          onClick={() => load(1)}
        >
          <Icon name="refresh" />
        </button>
      </div>
      {data.items.length ? (
        <ul id="execution-list" className="execution-list">
          {data.items.map((event, index) => (
            <li key={`${event.executed_at}-${event.user_id}-${index}`}>
              <div className="player-avatar" aria-hidden="true">
                {event.username.slice(0, 2).toUpperCase()}
              </div>
              <div className="execution-info">
                <div className="execution-player">
                  <a
                    href={`https://www.roblox.com/users/${event.user_id}/profile`}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {event.display_name}
                  </a>
                  <time
                    dateTime={new Date(event.executed_at * 1000).toISOString()}
                  >
                    {date(event.executed_at, true)}
                  </time>
                </div>
                <p>
                  @{event.username}
                  <span>·</span>ID {event.user_id}
                </p>
                <div className="execution-meta">
                  <span>Place {event.place_id}</span>
                  <span>Kinoue {event.library_version}</span>
                </div>
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <div id="execution-empty">
          <Empty title="No executions yet" icon="code">
            Successful script starts will appear here.
          </Empty>
        </div>
      )}
      <Pager
        page={data.page}
        total={data.total}
        size={data.page_size}
        noun="executions"
        busy={busy}
        onPage={load}
        prefix="execution"
      />
      <p className="history-note">
        Player identity is reported by the client. Times are recorded by the
        server and shown in your local timezone.
      </p>
    </section>
  );
}
