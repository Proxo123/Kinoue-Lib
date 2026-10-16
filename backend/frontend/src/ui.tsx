import { useLayoutEffect, useRef, useState, type ReactNode } from "react";
import { errorMessage } from "./api";
import type { Notify, Status } from "./types";

type IconName =
  | "key"
  | "code"
  | "search"
  | "plus"
  | "close"
  | "chevron"
  | "logout"
  | "copy"
  | "refresh"
  | "lock"
  | "arrow"
  | "check"
  | "settings";
const paths: Record<IconName, ReactNode> = {
  key: (
    <>
      <circle cx="8" cy="8" r="4" />
      <path d="m11 11 7 7m-3-3 3-3m-5 1 3-3" />
    </>
  ),
  code: (
    <>
      <path d="m7 5-5 5 5 5m6-10 5 5-5 5m-2-12-2 14" />
    </>
  ),
  search: (
    <>
      <circle cx="9" cy="9" r="6" />
      <path d="m14 14 4 4" />
    </>
  ),
  plus: <path d="M10 4v12M4 10h12" />,
  close: <path d="m5 5 10 10M15 5 5 15" />,
  chevron: <path d="m8 5 5 5-5 5" />,
  logout: (
    <>
      <path d="M8 3H3v14h5m5-11 4 4-4 4m-6-4h10" />
    </>
  ),
  copy: (
    <>
      <rect x="7" y="7" width="10" height="11" rx="2" />
      <path d="M13 7V3H3v10h4" />
    </>
  ),
  refresh: (
    <>
      <path d="M16 7a6.5 6.5 0 1 0 .2 6M16 3v4h-4" />
    </>
  ),
  lock: (
    <>
      <rect x="4" y="8" width="12" height="10" rx="2" />
      <path d="M6 8V6a4 4 0 0 1 8 0v2m-4 4v2" />
    </>
  ),
  arrow: <path d="M4 10h12m-5-5 5 5-5 5" />,
  check: <path d="m4 10 4 4 8-8" />,
  settings: (
    <>
      <circle cx="10" cy="10" r="3" />
      <path d="M8 2h4l.5 2 1.5 1 2-.5 2 3.5-1.5 1.5v2l1.5 1.5-2 3.5-2-.5-1.5 1-.5 2H8l-.5-2-1.5-1-2 .5-2-3.5L3.5 11V9L2 7.5 4 4l2 .5 1.5-1z" />
    </>
  ),
};
export function Icon({ name }: { name: IconName }) {
  return (
    <svg
      viewBox="0 0 20 20"
      width="18"
      height="18"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name]}
    </svg>
  );
}
export function Brand() {
  return (
    <span className="brand">
      <span>
        kinoue<span className="brand-period">.</span>
      </span>
    </span>
  );
}
export function Badge({ status }: { status: Status }) {
  return (
    <span className={`badge ${status}`}>
      <span />
      {status[0].toUpperCase() + status.slice(1)}
    </span>
  );
}

export function useTask(notify: Notify) {
  const [busy, setBusy] = useState(false);
  const running = useRef(false);
  async function run(operation: () => Promise<void>) {
    if (running.current) return;
    running.current = true;
    setBusy(true);
    try {
      await operation();
    } catch (error) {
      notify(errorMessage(error), true);
    } finally {
      running.current = false;
      setBusy(false);
    }
  }
  return { busy, run };
}

export function Dialog({
  id,
  title,
  subtitle,
  children,
  onClose,
  busy = false,
  drawer = false,
  initialFocus,
}: {
  id: string;
  title: string;
  subtitle?: string;
  children: ReactNode;
  onClose: () => void;
  busy?: boolean;
  drawer?: boolean;
  initialFocus?: string;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useLayoutEffect(() => {
    const dialog = ref.current!;
    dialog.showModal();
    if (initialFocus)
      dialog
        .querySelector<HTMLElement>(initialFocus)
        ?.focus({ preventScroll: true });
    return () => dialog.close();
  }, [initialFocus]);
  return (
    <dialog
      ref={ref}
      id={id}
      className={drawer ? "dialog drawer" : "dialog"}
      aria-labelledby={`${id}-title`}
      aria-busy={busy}
      onCancel={(event) => {
        event.preventDefault();
        if (!busy) onClose();
      }}
    >
      <header className="dialog-heading">
        <div>
          <h2 id={`${id}-title`}>{title}</h2>
          {subtitle ? <p>{subtitle}</p> : null}
        </div>
        <button
          className="icon-button close"
          aria-label="Close"
          onClick={onClose}
          disabled={busy}
        >
          <Icon name="close" />
        </button>
      </header>
      {children}
    </dialog>
  );
}

export function Pager({
  page,
  total,
  size,
  noun,
  busy,
  onPage,
  prefix = "",
}: {
  page: number;
  total: number;
  size: number;
  noun: string;
  busy: boolean;
  onPage: (page: number) => void;
  prefix?: string;
}) {
  return (
    <div className="pagination">
      <span id={prefix ? `${prefix}-count` : "result-count"} className="muted">
        {total
          ? `${(page - 1) * size + 1}–${Math.min(page * size, total)} of ${total} ${noun}`
          : `0 ${noun}`}
      </span>
      <div className="pagination-buttons">
        <button
          id={prefix ? `previous-${prefix}s` : "previous"}
          className="icon-button previous"
          aria-label={`Previous ${noun} page`}
          disabled={busy || page <= 1}
          onClick={() => onPage(page - 1)}
        >
          <Icon name="chevron" />
        </button>
        <span className="page-indicator">
          Page <span id={prefix ? undefined : "page-number"}>{page}</span>
        </span>
        <button
          id={prefix ? `next-${prefix}s` : "next"}
          className="icon-button"
          aria-label={`Next ${noun} page`}
          disabled={busy || page * size >= total}
          onClick={() => onPage(page + 1)}
        >
          <Icon name="chevron" />
        </button>
      </div>
    </div>
  );
}

export function Empty({
  title,
  children,
  icon = "key",
}: {
  title: string;
  children: ReactNode;
  icon?: IconName;
}) {
  return (
    <div className="empty" id="empty">
      <span className="empty-icon">
        <Icon name={icon} />
      </span>
      <h3>{title}</h3>
      <p>{children}</p>
    </div>
  );
}

export async function copy(value: string, notify: Notify) {
  try {
    await navigator.clipboard.writeText(value);
    notify("Copied to clipboard.");
  } catch {
    notify("Select the text and copy it manually.", true);
  }
}
