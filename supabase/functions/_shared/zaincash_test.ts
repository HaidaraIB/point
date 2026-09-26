import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  extractZaincashTokenFromSearch,
  mapZaincashPaymentStatus,
  normalizeZaincashRef,
  parseZaincashCallbackPayload,
} from "./zaincash.ts";

Deno.test("mapZaincashPaymentStatus", () => {
  assertEquals(mapZaincashPaymentStatus("SUCCESS"), "paid");
  assertEquals(mapZaincashPaymentStatus("PENDING"), "pending");
  assertEquals(mapZaincashPaymentStatus("OTP_SENT"), "pending");
  assertEquals(
    mapZaincashPaymentStatus("CUSTOMER_AUTHENTICATION_REQUIRED"),
    "pending",
  );
  assertEquals(mapZaincashPaymentStatus("FAILED"), "failed");
  assertEquals(mapZaincashPaymentStatus("EXPIRED"), "failed");
});

Deno.test("normalizeZaincashRef strips glued token suffix", () => {
  const uuid = "75b5e2b0-6503-4685-8ac7-6268802377c5";
  assertEquals(
    normalizeZaincashRef(`${uuid}?token=eyJhbGciOiJIUzI1NiJ9`),
    uuid,
  );
  assertEquals(normalizeZaincashRef(uuid), uuid);
});

Deno.test("extractZaincashTokenFromSearch", () => {
  const jwt = "eyJhbGciOiJIUzI1NiJ9.abc.def";
  const search =
    "?provider=zaincash&ref=75b5e2b0-6503-4685-8ac7-6268802377c5?token=" +
    jwt;
  assertEquals(extractZaincashTokenFromSearch(search), jwt);
  assertEquals(
    extractZaincashTokenFromSearch("?provider=zaincash&token=" + jwt),
    jwt,
  );
});

Deno.test("parseZaincashCallbackPayload", () => {
  const info = parseZaincashCallbackPayload({
    data: {
      transactionId: "txn-1",
      orderId: "inv-1",
      currentStatus: "SUCCESS",
    },
  });
  assertEquals(info?.transactionId, "txn-1");
  assertEquals(info?.orderId, "inv-1");
  assertEquals(info?.currentStatus, "SUCCESS");
});
