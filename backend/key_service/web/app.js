"use strict";

const $ = (id) => document.getElementById(id);
const state = { csrf: "", applications: [], page: 1, total: 0, detail: null, generation: 0 };
const messages = {
  invalid_admin_password: "Incorrect password.",
  admin_login_required: "Sign in again.",
  admin_unconfigured: "Admin password is not configured.",
  admin_origin_unconfigured: "Admin site origin is not configured.",
  invalid_origin: "This site address is not allowed.",
  invalid_csrf: "Refresh the page and try again.",
  invalid_request: "Check the entered values.",
  request_too_large: "File is too large.",
  rate_limited: "Too many requests. Try again shortly.",
  not_found: "Key no longer exists.",
};
const actions = { key_created: "Key created", key_revoked: "Key revoked", hwid_reset: "HWID reset", set_hwid: "HWID replaced", renew: "Key renewed", restore: "Key restored", delete: "Key deleted" };
let toastTimer;
let searchTimer;

function notify(message, error = false) {
  $("toast").textContent = message;
  $("toast").classList.toggle("error-toast", error);
  $("toast").hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { $("toast").hidden = true; }, 4500);
}

function showLogin() {
  state.csrf = "";
  state.detail = null;
  state.generation += 1;
  $("dashboard").hidden = true;
  $("login-view").hidden = false;
  $("key-rows").replaceChildren();
  $("bound-hwid").value = "";
  $("new-key").value = "";
  document.querySelectorAll("dialog[open]").forEach((dialog) => dialog.close());
}

async function api(path, options = {}) {
  const headers = { ...options.headers };
  if (options.body !== undefined) {
    headers["Content-Type"] = "application/json";
    headers["X-CSRF-Token"] = state.csrf;
  }
  let response;
  try {
    response = await fetch("/admin/api" + path, {
      ...options,
      headers,
      body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
      cache: "no-store",
      credentials: "same-origin",
    });
  } catch {
    throw new Error("Could not connect to the server.");
  }
  let data;
  try { data = await response.json(); } catch { throw new Error("Server returned an invalid response."); }
  if (!response.ok) {
    if (data.error === "admin_login_required") showLogin();
    throw new Error(messages[data.error] || "Request failed. Try again.");
  }
  return data;
}

function element(tag, text, className) {
  const item = document.createElement(tag);
  if (text !== undefined) item.textContent = text;
  if (className) item.className = className;
  return item;
}

function date(value, time = false) {
  return value ? new Date(value * 1000).toLocaleString(undefined, time ? { dateStyle: "medium", timeStyle: "short" } : { dateStyle: "medium" }) : "—";
}

function scriptName(id) {
  return state.applications.find((app) => app.id === id)?.name || id;
}

async function busy(form, operation) {
  if (form.dataset.busy) return;
  form.dataset.busy = "true";
  form.inert = true;
  form.setAttribute("aria-busy", "true");
  try { await operation(); } catch (error) { notify(error.message, true); } finally {
    delete form.dataset.busy;
    form.inert = false;
    form.removeAttribute("aria-busy");
  }
}

async function loadApplications() {
  state.applications = (await api("/applications")).items;
  const filterValue = $("app-filter").value;
  $("app-filter").replaceChildren(new Option("All scripts", ""));
  $("create-application").replaceChildren();
  $("script-list").replaceChildren();
  for (const app of state.applications) {
    $("app-filter").add(new Option(app.name, app.id));
    $("create-application").add(new Option(app.name, app.id));
    const row = element("div", undefined, "script-row");
    const text = element("div");
    text.append(element("strong", app.name), element("p", app.id + " · " + Math.ceil((app.source_size || 0) / 1024) + " KB", "muted mono"));
    const update = element("button", "Update", "secondary");
    update.type = "button";
    update.addEventListener("click", () => {
      $("script-id").value = app.id;
      $("script-id").readOnly = true;
      $("script-name").value = app.name;
      $("script-file").value = "";
      $("script-form-title").textContent = "Update script";
      $("cancel-script-edit").hidden = false;
      $("script-file").focus();
    });
    row.append(text, update);
    $("script-list").append(row);
  }
  if (state.applications.some((app) => app.id === filterValue)) $("app-filter").value = filterValue;
  $("open-create").disabled = state.applications.length === 0;
  if (!state.applications.length) $("script-list").append(element("p", "No scripts yet.", "muted"));
}

async function loadKeys() {
  const generation = ++state.generation;
  const query = new URLSearchParams({ application: $("app-filter").value, status: $("status-filter").value, search: $("search").value.trim(), page: state.page });
  const data = await api("/licenses?" + query);
  if (generation !== state.generation || !state.csrf) return;
  if (state.page > 1 && !data.items.length) {
    state.page = Math.max(1, Math.ceil(data.total / 50));
    return loadKeys();
  }
  state.total = data.total;
  $("key-rows").replaceChildren();
  for (const key of data.items) {
    const row = element("tr");
    const name = element("td");
    name.append(element("div", key.label || "Unlabeled key", "key-label"), element("div", key.key_hint || key.id.slice(0, 12), "key-hint"));
    const script = element("td", scriptName(key.application));
    const status = element("td");
    status.append(element("span", key.status[0].toUpperCase() + key.status.slice(1), "badge " + key.status));
    const hwid = element("td");
    hwid.append(element("span", key.hwid_bound ? "Bound" : "Unbound", "bound " + (key.hwid_bound ? "yes" : "")));
    const expiry = element("td", date(key.expires_at), "muted");
    const action = element("td");
    const manage = element("button", "Manage ↗", "quiet");
    manage.type = "button";
    manage.setAttribute("aria-label", "Manage " + (key.label || key.key_hint || key.id));
    manage.addEventListener("click", () => busy(row, () => openDetail(key.id)));
    action.append(manage);
    row.append(name, script, status, hwid, expiry, action);
    $("key-rows").append(row);
  }
  $("empty").hidden = data.items.length > 0;
  const filtered = $("search").value || $("status-filter").value || $("app-filter").value;
  $("empty").querySelector("h2").textContent = filtered ? "No matching keys" : "No keys yet";
  $("empty").querySelector("p").textContent = filtered ? "Adjust the search or filters." : "Create a key to grant access.";
  $("result-count").textContent = data.total ? `${(state.page - 1) * 50 + 1}–${Math.min(state.page * 50, data.total)} of ${data.total} keys` : "0 keys";
  $("page-number").textContent = String(state.page).padStart(2, "0");
  $("previous").disabled = state.page <= 1;
  $("next").disabled = state.page * 50 >= data.total;
}

async function dashboard() {
  $("login-view").hidden = true;
  $("dashboard").hidden = false;
  await loadApplications();
  await loadKeys();
}

async function openDetail(id) {
  const detail = await api("/licenses/" + encodeURIComponent(id));
  if (!state.csrf) return;
  state.detail = detail;
  $("detail-title").textContent = detail.label || detail.key_hint || "Key";
  $("detail-script").textContent = scriptName(detail.application) + " / " + detail.id.slice(0, 12);
  $("detail-status").textContent = detail.status[0].toUpperCase() + detail.status.slice(1);
  $("detail-status").className = "badge " + detail.status;
  $("detail-expiry").textContent = "Expires " + date(detail.expires_at);
  $("bound-hwid").value = detail.hwid || (detail.hwid_bound ? "Fingerprint: " + detail.hwid_fingerprint : "Unbound");
  $("copy-hwid").disabled = !detail.hwid;
  $("reset-hwid").disabled = !detail.hwid_bound;
  $("replacement-hwid").value = "";
  $("revoke-key").textContent = detail.status === "revoked" ? "Restore key" : "Revoke key";
  $("activity-list").replaceChildren();
  for (const event of detail.activity) {
    const row = element("li");
    row.append(element("span", actions[event.action] || event.action), element("time", date(event.created_at, true), "muted"));
    $("activity-list").append(row);
  }
  if (!$("detail-dialog").open) $("detail-dialog").showModal();
}

async function change(action, value, message) {
  if (!state.detail) return;
  const id = state.detail.id;
  await api("/licenses/" + encodeURIComponent(id), { method: "POST", body: { action, value } });
  if (action === "delete") $("detail-dialog").close();
  else await openDetail(id);
  await loadKeys();
  notify(message);
}

async function copy(value) {
  if (!value) return;
  try { await navigator.clipboard.writeText(value); notify("Copied."); } catch { notify("Select the text and copy it.", true); }
}

function resetScriptForm() {
  $("script-form").reset();
  $("script-id").readOnly = false;
  $("script-form-title").textContent = "Add script";
  $("cancel-script-edit").hidden = true;
}

$("login-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  $("login-error").textContent = "";
  const button = $("login-form").querySelector("button");
  button.disabled = true;
  try {
    state.csrf = (await api("/login", { method: "POST", body: { password: $("password").value } })).csrf;
    $("password").value = "";
    await dashboard();
  } catch (error) { $("login-error").textContent = error.message; } finally { button.disabled = false; }
});

$("logout").addEventListener("click", () => busy($("dashboard"), async () => {
  await api("/logout", { method: "POST", body: {} });
  showLogin();
}));

$("open-create").addEventListener("click", () => {
  $("create-form").reset();
  if ($("app-filter").value) $("create-application").value = $("app-filter").value;
  $("create-dialog").showModal();
});

$("create-form").addEventListener("submit", (event) => {
  event.preventDefault();
  busy($("create-form"), async () => {
    const result = await api("/licenses", { method: "POST", body: { application: $("create-application").value, label: $("create-label").value, days: Number($("create-days").value) } });
    $("create-dialog").close();
    $("new-key").value = result.key;
    $("created-dialog").showModal();
    state.page = 1;
    await loadKeys();
  });
});

$("copy-key").addEventListener("click", () => copy($("new-key").value));
$("created-dialog").addEventListener("close", () => { $("new-key").value = ""; });
$("detail-dialog").addEventListener("close", () => { state.detail = null; $("bound-hwid").value = ""; $("replacement-hwid").value = ""; });
$("copy-hwid").addEventListener("click", () => copy(state.detail?.hwid));
$("reset-hwid").addEventListener("click", () => busy($("detail-dialog"), () => change("reset-hwid", null, "HWID lock reset.")));
$("hwid-form").addEventListener("submit", (event) => {
  event.preventDefault();
  busy($("detail-dialog"), () => change("set-hwid", $("replacement-hwid").value, "HWID replaced."));
});
$("renew-form").addEventListener("submit", (event) => {
  event.preventDefault();
  busy($("detail-dialog"), () => change("renew", Number($("renew-days").value), "Key renewed."));
});
$("revoke-key").addEventListener("click", () => busy($("detail-dialog"), () => {
  const restore = state.detail?.status === "revoked";
  return change(restore ? "restore" : "revoke", null, restore ? "Key restored." : "Key revoked.");
}));
$("delete-key").addEventListener("click", () => {
  if (confirm("Permanently delete this key?")) busy($("detail-dialog"), () => change("delete", null, "Key deleted."));
});

$("open-scripts").addEventListener("click", () => { resetScriptForm(); $("scripts-dialog").showModal(); });
$("cancel-script-edit").addEventListener("click", resetScriptForm);
$("script-form").addEventListener("submit", (event) => {
  event.preventDefault();
  busy($("script-form"), async () => {
    const file = $("script-file").files[0];
    if (!file || file.size === 0 || file.size > 2097152) throw new Error("Choose a Luau file smaller than 2 MB.");
    await api("/applications", { method: "POST", body: { id: $("script-id").value, name: $("script-name").value, source: await file.text() } });
    resetScriptForm();
    await loadApplications();
    await loadKeys();
    notify("Script saved.");
  });
});

document.querySelectorAll(".close").forEach((button) => button.addEventListener("click", () => button.closest("dialog").close()));
document.querySelectorAll("dialog").forEach((dialog) => dialog.addEventListener("cancel", (event) => { if (dialog.dataset.busy) event.preventDefault(); }));
$("previous").addEventListener("click", () => { state.page = Math.max(1, state.page - 1); loadKeys().catch((error) => notify(error.message, true)); });
$("next").addEventListener("click", () => { state.page += 1; loadKeys().catch((error) => notify(error.message, true)); });
for (const id of ["app-filter", "status-filter"]) $(id).addEventListener("change", () => { state.page = 1; loadKeys().catch((error) => notify(error.message, true)); });
$("search").addEventListener("input", () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => { state.page = 1; loadKeys().catch((error) => notify(error.message, true)); }, 300);
});

(async () => {
  try { state.csrf = (await api("/me")).csrf; await dashboard(); } catch (error) {
    showLogin();
    if (error.message !== "Sign in again.") $("login-error").textContent = error.message;
  }
})();
