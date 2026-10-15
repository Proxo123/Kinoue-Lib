import { useState, type FormEvent } from "react";
import { Dialog, Empty, Icon, useTask } from "./ui";
import type { Api, Application, Notify } from "./types";

export function Scripts({
  api,
  notify,
  applications,
  loaded,
  onSaved,
}: {
  api: Api;
  notify: Notify;
  applications: Application[];
  loaded: boolean;
  onSaved: () => void;
}) {
  const [edit, setEdit] = useState<Application | "new" | null>(null);
  return (
    <>
      <div className="page-heading">
        <div>
          <div className="title-row">
            <h1>Scripts</h1>
            <span className="count-tag">{applications.length}</span>
          </div>
          <p>The private payloads your keys give access to.</p>
        </div>
        <button
          className="button primary"
          id="add-script"
          onClick={() => setEdit("new")}
        >
          <Icon name="plus" />
          Add script
        </button>
      </div>
      <section className="table-panel" aria-label="Registered scripts">
        <div className="panel-heading">
          <h2>Registered scripts</h2>
          <span className="muted">Luau payloads</span>
        </div>
        {applications.length ? (
          <div className="table-scroll">
            <table className="scripts-table">
              <thead>
                <tr>
                  <th>Script</th>
                  <th>Application ID</th>
                  <th>Payload size</th>
                  <th>
                    <span className="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody id="script-list">
                {applications.map((app) => (
                  <tr key={app.id} className="script-row">
                    <td>
                      <span className="script-name">
                        <span className="script-file-icon">
                          <Icon name="code" />
                        </span>
                        <strong>{app.name}</strong>
                      </span>
                    </td>
                    <td className="mono muted">{app.id}</td>
                    <td className="muted">
                      {(app.source_size / 1024).toLocaleString(undefined, {
                        maximumFractionDigits: 1,
                      })}{" "}
                      KB
                    </td>
                    <td className="row-action">
                      <button
                        className="button secondary small"
                        onClick={() => setEdit(app)}
                        aria-label={`Update ${app.name}`}
                      >
                        Update
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : loaded ? (
          <Empty title="Add your first script" icon="code">
            Upload a Luau file, then create keys to share access.
          </Empty>
        ) : (
          <p className="table-loading" role="status">
            Loading scripts…
          </p>
        )}
      </section>
      <p className="page-note">
        <Icon name="lock" />
        Updating a payload keeps its existing keys working.
      </p>
      {edit ? (
        <ScriptForm
          key={edit === "new" ? "new" : edit.id}
          application={edit === "new" ? null : edit}
          api={api}
          notify={notify}
          onClose={() => setEdit(null)}
          onSaved={() => {
            setEdit(null);
            onSaved();
          }}
        />
      ) : null}
    </>
  );
}

function ScriptForm({
  application,
  api,
  notify,
  onClose,
  onSaved,
}: {
  application: Application | null;
  api: Api;
  notify: Notify;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [filename, setFilename] = useState("");
  const { busy, run } = useTask(notify);
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const fields = new FormData(event.currentTarget);
    run(async () => {
      const file = fields.get("file");
      if (!(file instanceof File) || !file.size || file.size > 2097152)
        throw new Error("Choose a non-empty Luau file smaller than 2 MB.");
      const source = await file.text();
      if (source.length > 2097152) throw new Error("The script is too large.");
      await api("/applications", {
        id: fields.get("id"),
        name: fields.get("name"),
        source,
      });
      onSaved();
      notify(application ? "Script updated." : "Script added.");
    });
  }
  return (
    <Dialog
      id="scripts-dialog"
      initialFocus="#script-name"
      title={application ? `Update ${application.name}` : "Add a script"}
      subtitle={
        application
          ? "Upload a replacement payload for this script."
          : "Give your script a name and upload its payload."
      }
      onClose={onClose}
      busy={busy}
    >
      <form id="script-form" onSubmit={submit}>
        <fieldset disabled={busy} className="dialog-body form-stack">
          <div>
            <label htmlFor="script-name">Script name</label>
            <input
              id="script-name"
              name="name"
              required
              maxLength={80}
              defaultValue={application?.name || ""}
              placeholder="King"
              autoFocus
            />
          </div>
          <div>
            <label htmlFor="script-id">Application ID</label>
            <input
              id="script-id"
              className="mono"
              name="id"
              required
              pattern={"[a-z][a-z0-9_\\-]{0,63}"}
              maxLength={64}
              readOnly={Boolean(application)}
              defaultValue={application?.id || ""}
              placeholder="king"
            />
            <p className="field-note">
              {application
                ? "The ID stays the same so existing keys keep working."
                : "Lowercase letters, numbers, dashes and underscores."}
            </p>
          </div>
          <div>
            <label htmlFor="script-file">Luau file</label>
            <div className="file-input">
              <Icon name="code" />
              <span>{filename || "Choose a .luau or .lua file"}</span>
              <input
                id="script-file"
                name="file"
                type="file"
                accept=".luau,.lua,text/plain"
                required
                onChange={(event) =>
                  setFilename(event.target.files?.[0]?.name || "")
                }
              />
              <span className="file-button">Browse</span>
            </div>
            <p className="field-note">Up to 2 MB. Stored privately.</p>
          </div>
        </fieldset>
        <footer className="dialog-footer">
          <button
            className="button secondary"
            type="button"
            onClick={onClose}
            disabled={busy}
          >
            Cancel
          </button>
          <button className="button primary" disabled={busy}>
            {busy ? "Saving…" : "Save script"}
          </button>
        </footer>
      </form>
    </Dialog>
  );
}
