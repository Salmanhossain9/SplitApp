// Firebase Cloud Messaging HTTP v1 from an Edge Function, using a service account in the
// FCM_SERVICE_ACCOUNT secret (the JSON file contents). No SDK: sign a JWT with Web Crypto,
// trade it for an access token, POST the message.
import { encodeBase64 } from "@std/encoding/base64";

interface ServiceAccount { project_id: string; client_email: string; private_key: string }

const b64url = (data: string | Uint8Array): string => {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  return encodeBase64(bytes).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
};

export async function signServiceJwt(sa: ServiceAccount, nowSeconds: number): Promise<string> {
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`)));
  return `${header}.${claims}.${b64url(sig)}`;
}

export function fcmMessage(token: string, title: string, body: string, data: Record<string, string>) {
  return { message: { token, notification: { title, body }, data, android: { priority: "HIGH" } } };
}

export type PushResult = "sent" | "no_config" | "invalid_token" | "failed";

export async function sendPush(token: string, title: string, body: string, data: Record<string, string>): Promise<PushResult> {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) return "no_config";
  const sa = JSON.parse(raw) as ServiceAccount;
  const jwt = await signServiceJwt(sa, Math.floor(Date.now() / 1000));
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  if (!tokenRes.ok) return "failed";
  const { access_token } = await tokenRes.json();
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${access_token}`, "content-type": "application/json" },
    body: JSON.stringify(fcmMessage(token, title, body, data)),
  });
  if (res.ok) return "sent";
  if (res.status === 404 || res.status === 400) return "invalid_token";
  return "failed";
}
