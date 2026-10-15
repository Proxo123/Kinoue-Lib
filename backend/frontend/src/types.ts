export interface Application {
  id: string;
  name: string;
  enabled: boolean;
  source_size: number;
}
export type Status = "active" | "expired" | "revoked";
export interface License {
  id: string;
  application: string;
  label: string;
  key_hint: string;
  expires_at: number | null;
  created_at: number;
  last_seen: number | null;
  hwid_bound: boolean;
  status: Status;
}
export interface Page<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
}
export interface Execution {
  user_id: number;
  username: string;
  display_name: string;
  place_id: number;
  library_version: string;
  executed_at: number;
}
export interface Detail extends License {
  hwid: string | null;
  hwid_fingerprint: string | null;
  activity: { action: string; created_at: number }[];
  executions: Page<Execution>;
}
export type Api = <T>(
  path: string,
  body?: unknown,
  signal?: AbortSignal,
) => Promise<T>;
export type Notify = (message: string, error?: boolean) => void;
export type Action =
  "revoke" | "restore" | "reset-hwid" | "set-hwid" | "renew" | "delete";
