import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { mapZaincashPaymentStatus } from "./zaincash.ts";

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
