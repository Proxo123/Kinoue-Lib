import { useEffect, useState, type FormEvent } from "react";
import { date, errorMessage, remaining } from "./api";
import { KeyDetail } from "./KeyDetail";
import { Badge, copy, Dialog, Empty, Icon, Pager, useTask } from "./ui";
import type { Api, Application, License, Notify, Page, Status } from "./types";

const statuses: { value: Status | ""; label: string }[] = [
  { value: "", label: "All keys" },
  { value: "active", label: "Active" },
  { value: "expired", label: "Expired" },
  { value: "revoked", label: "Revoked" },
];

export function Keys({
  api,
  notify,
  applications,
  applicationsLoaded,
  onScripts,
}: {
  api: Api;
  notify: Notify;
  applications: Application[];
  applicationsLoaded: boolean;
  onScripts: () => void;
}) {
  const [query, setQuery] = useState({
    search: "",
    application: "",
    status: "",
    page: 1,
  });
  const [data, setData] = useState<Page<License> | null>(null);
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState("");
  const [refresh, setRefresh] = useState(0);
  const [create, setCreate] = useState(false);
  const [created, setCreated] = useState<{
    key: string;
    expires_at: number;
  } | null>(null);
  const [detail, setDetail] = useState<string | null>(null);
  const { search, application, status, page } = query;
  useEffect(() => {
    const controller = new AbortController();
    setBusy(true);
    setError("");
    const timer = setTimeout(
      async () => {
        try {
          const params = new URLSearchParams({
            search: search.trim(),
            application,
            status,
            page: String(page),
          });
          const result = await api<Page<License>>(
            "/licenses?" + params,
            undefined,
            controller.signal,
          );
          if (controller.signal.aborted) return;
          if (page > 1 && !result.items.length) {
            setQuery((value) => ({
              ...value,
              page: Math.max(1, Math.ceil(result.total / result.page_size)),
            }));
            return;
          }
          setData(result);
        } catch (error) {
          if (!controller.signal.aborted) setError(errorMessage(error));
        } finally {
          if (!controller.signal.aborted) setBusy(false);
        }
      },
      search ? 300 : 0,
    );
    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [api, search, application, status, page, refresh]);
  function filter(value: Partial<typeof query>) {
    setQuery((current) => ({ ...current, ...value, page: 1 }));
  }
  const filtered = Boolean(search || application || status);
  const scriptName = (id: string) =>
    applications.find((app) => app.id === id)?.name || id;
  return (
    <>
      <div className="page-heading">
        <div>
          <div className="title-row">
            <h1>Access keys</h1>
            {data ? <span className="count-tag">{data.total}</span> : null}
          </div>
          <p>Manage script access and the people using it.</p>
        </div>
        <button
          id="open-create"
          className="button primary"
          disabled={!applications.length}
          onClick={() => setCreate(true)}
        >
          <Icon name="plus" />
          New key
        </button>
      </div>
      <section className="table-panel" aria-label="Access keys">
        <div className="table-toolbar">
          <div className="status-filters" aria-label="Key status">
            {statuses.map((item) => (
              <button
                key={item.value}
                className={status === item.value ? "active" : ""}
                aria-pressed={status === item.value}
                onClick={() => filter({ status: item.value })}
              >
                {item.label}
              </button>
            ))}
          </div>
          <button
            className="icon-button"
            aria-label="Refresh keys"
            disabled={busy}
            onClick={() => setRefresh((value) => value + 1)}
          >
            <Icon name="refresh" />
          </button>
        </div>
        <div className="filter-row">
          <div className="search-field">
            <Icon name="search" />
            <input
              id="search"
              type="search"
              aria-label="Search keys"
              placeholder="Search by label, key or ID…"
              maxLength={120}
              value={search}
              onChange={(event) => filter({ search: event.target.value })}
            />
          </div>
          <div className="script-filter">
            <label htmlFor="app-filter">Script</label>
            <select
              id="app-filter"
              aria-label="Filter by script"
              value={application}
              onChange={(event) => filter({ application: event.target.value })}
            >
              <option value="">All scripts</option>
              {applications.map((app) => (
                <option key={app.id} value={app.id}>
                  {app.name}
                </option>
              ))}
            </select>
          </div>
        </div>
        {error ? (
          <div className="error-banner" role="alert">
            {error}
            <button
              className="text-button"
              onClick={() => setRefresh((value) => value + 1)}
            >
              Retry
            </button>
          </div>
        ) : null}
        <div
          className={`table-scroll ${busy ? "is-loading" : ""}`}
          aria-busy={busy}
        >
          <table className="keys-table">
            <thead>
              <tr>
                <th>Key / label</th>
                <th className="script-column">Script</th>
                <th>Status</th>
                <th className="device-column">Device</th>
                <th className="expiry-column">Expires</th>
                <th>
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody id="key-rows">
              {data?.items.map((key) => (
                <tr key={key.id}>
                  <td>
                    <button
                      className="key-name"
                      onClick={() => setDetail(key.id)}
                    >
                      {key.label || "Unlabeled key"}
                    </button>
                    <div className="key-hint mono">
                      {key.key_hint || key.id.slice(0, 12)}
                    </div>
                    <small className="mobile-script">
                      {scriptName(key.application)}
                    </small>
                  </td>
                  <td className="script-column">
                    <span className="script-name">
                      <Icon name="code" />
                      {scriptName(key.application)}
                    </span>
                  </td>
                  <td>
                    <Badge status={key.status} />
                  </td>
                  <td className="device-column">
                    <span className={key.hwid_bound ? "device-bound" : "muted"}>
                      {key.hwid_bound ? (
                        <>
                          <Icon name="lock" />
                          Bound
                        </>
                      ) : (
                        "Unbound"
                      )}
                    </span>
                  </td>
                  <td className="expiry-column">
                    <span>{date(key.expires_at)}</span>
                    <small className="muted">{remaining(key.expires_at)}</small>
                  </td>
                  <td className="row-action">
                    <button
                      className="icon-button"
                      aria-label={`Manage ${key.label || key.key_hint || key.id}`}
                      onClick={() => setDetail(key.id)}
                    >
                      <Icon name="chevron" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!data && busy ? (
          <div className="table-loading" role="status">
            Loading keys…
          </div>
        ) : !busy && !error && data?.items.length === 0 ? (
          <Empty title={filtered ? "No matching keys" : "No keys yet"}>
            {filtered ? (
              <button
                className="text-button"
                onClick={() =>
                  setQuery({ search: "", application: "", status: "", page: 1 })
                }
              >
                Clear the filters
              </button>
            ) : applicationsLoaded && !applications.length ? (
              <button className="text-button" onClick={onScripts}>
                Add a script to create your first key.
              </button>
            ) : (
              "Create a key to give someone access to a script."
            )}
          </Empty>
        ) : null}
        <Pager
          page={data?.page || 1}
          total={data?.total || 0}
          size={data?.page_size || 50}
          noun="keys"
          busy={busy}
          onPage={(page) => setQuery((value) => ({ ...value, page }))}
        />
      </section>
      <p className="page-note">
        <Icon name="lock" />
        Full key values are only shown when you create them.
      </p>
      {create ? (
        <CreateKey
          api={api}
          notify={notify}
          applications={applications}
          initialApplication={application}
          onClose={() => setCreate(false)}
          onCreated={(result) => {
            setCreate(false);
            setCreated(result);
            setQuery((value) => ({ ...value, page: 1 }));
            setRefresh((value) => value + 1);
          }}
        />
      ) : null}
      {created ? (
        <Dialog
          id="created-dialog"
          initialFocus="#new-key"
          title="Your key is ready"
          subtitle="Copy it now. The full key won’t be shown again."
          onClose={() => setCreated(null)}
        >
          <div className="dialog-body">
            <label htmlFor="new-key">Access key</label>
            <textarea
              id="new-key"
              className="mono issued-key"
              readOnly
              value={created.key}
              onFocus={(event) => event.target.select()}
              autoFocus
            />
            <p className="muted">Expires {date(created.expires_at)}</p>
          </div>
          <footer className="dialog-footer">
            <button
              className="button secondary"
              onClick={() => setCreated(null)}
            >
              Done
            </button>
            <button
              className="button primary"
              id="copy-key"
              onClick={() => copy(created.key, notify)}
            >
              <Icon name="copy" />
              Copy key
            </button>
          </footer>
        </Dialog>
      ) : null}
      {detail ? (
        <KeyDetail
          key={detail}
          id={detail}
          api={api}
          notify={notify}
          scriptName={scriptName}
          onClose={() => setDetail(null)}
          onChanged={() => setRefresh((value) => value + 1)}
        />
      ) : null}
    </>
  );
}

function CreateKey({
  api,
  notify,
  applications,
  initialApplication,
  onClose,
  onCreated,
}: {
  api: Api;
  notify: Notify;
  applications: Application[];
  initialApplication: string;
  onClose: () => void;
  onCreated: (result: { key: string; expires_at: number }) => void;
}) {
  const [application, setApplication] = useState(
    initialApplication || applications[0]?.id || "",
  );
  const { busy, run } = useTask(notify);
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const fields = new FormData(event.currentTarget);
    run(async () =>
      onCreated(
        await api("/licenses", {
          application,
          label: fields.get("label"),
          days: Number(fields.get("days")),
        }),
      ),
    );
  }
  return (
    <Dialog
      id="create-dialog"
      initialFocus="#create-label"
      title="Create an access key"
      subtitle="Choose a script and how long access should last."
      onClose={onClose}
      busy={busy}
    >
      <form id="create-form" onSubmit={submit}>
        <fieldset disabled={busy} className="dialog-body form-stack">
          <div>
            <label htmlFor="create-label">
              Label <span className="muted">Optional</span>
            </label>
            <input
              id="create-label"
              name="label"
              maxLength={120}
              placeholder="e.g. Player name"
              autoFocus
            />
          </div>
          <div>
            <label htmlFor="create-application">Script</label>
            <select
              id="create-application"
              value={application}
              onChange={(event) => setApplication(event.target.value)}
              required
            >
              {applications.map((app) => (
                <option key={app.id} value={app.id}>
                  {app.name}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="create-days">Valid for</label>
            <div className="input-suffix">
              <input
                id="create-days"
                name="days"
                type="number"
                required
                defaultValue={30}
                min={1}
                max={3650}
              />
              <span>days</span>
            </div>
            <p className="field-note">Starts today, when the key is created.</p>
          </div>
        </fieldset>
        <footer className="dialog-footer">
          <button
            type="button"
            className="button secondary"
            onClick={onClose}
            disabled={busy}
          >
            Cancel
          </button>
          <button className="button primary" disabled={busy}>
            {busy ? "Creating…" : "Create key"}
          </button>
        </footer>
      </form>
    </Dialog>
  );
}
