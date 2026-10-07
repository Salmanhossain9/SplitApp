import { assertEquals } from "@std/assert";
import { fcmMessage, signServiceJwt } from "./fcm.ts";

const dec = (s: string) => Uint8Array.from(atob(s.replaceAll("-", "+").replaceAll("_", "/")), (c) => c.charCodeAt(0));

Deno.test("service account JWT is RS256 with the FCM scope and verifies", async () => {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true, ["sign", "verify"],
  ) as CryptoKeyPair;
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  let bin = "";
  for (const b of pkcs8) bin += String.fromCharCode(b);
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(bin)}\n-----END PRIVATE KEY-----\n`;

  const jwt = await signServiceJwt({ project_id: "p", client_email: "svc@p.iam.gserviceaccount.com", private_key: pem }, 1_800_000_000);
  const [h, c, s] = jwt.split(".") as [string, string, string];
  assertEquals(JSON.parse(new TextDecoder().decode(dec(h))), { alg: "RS256", typ: "JWT" });
  const claims = JSON.parse(new TextDecoder().decode(dec(c)));
  assertEquals(claims.iss, "svc@p.iam.gserviceaccount.com");
  assertEquals(claims.scope, "https://www.googleapis.com/auth/firebase.messaging");
  assertEquals(claims.exp - claims.iat, 3600);
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", pair.publicKey, dec(s), new TextEncoder().encode(`${h}.${c}`));
  assertEquals(ok, true);
});

Deno.test("fcm message shape", () => {
  const m = fcmMessage("tok", "t", "b", { kind: "remind" });
  assertEquals(m.message.token, "tok");
  assertEquals(m.message.notification, { title: "t", body: "b" });
  assertEquals(m.message.data, { kind: "remind" });
});
