import {
  assertEquals,
} from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  buildQicardWebhookDataString,
  formatQicardWebhookAmount,
  mapQicardPaymentStatus,
} from "./qicard.ts";

Deno.test("formatQicardWebhookAmount appends .000", () => {
  assertEquals(formatQicardWebhookAmount(10000), "10000.000");
});

Deno.test("buildQicardWebhookDataString matches docs order", () => {
  const s = buildQicardWebhookDataString({
    paymentId: "b91e8d70-1ab7-4275-85a2-61f7dbb31410",
    amount: 10000,
    currency: "IQD",
    creationDate: "2025-01-13T21:25:19",
    status: "SUCCESS",
  });
  assertEquals(
    s,
    "b91e8d70-1ab7-4275-85a2-61f7dbb31410|10000.000|IQD|2025-01-13T21:25:19|SUCCESS",
  );
});

Deno.test("mapQicardPaymentStatus", () => {
  assertEquals(mapQicardPaymentStatus("SUCCESS", false), "paid");
  assertEquals(mapQicardPaymentStatus("CREATED", false), "pending");
  assertEquals(mapQicardPaymentStatus("CREATED", true), "failed");
  assertEquals(mapQicardPaymentStatus("FAILED", false), "failed");
});
