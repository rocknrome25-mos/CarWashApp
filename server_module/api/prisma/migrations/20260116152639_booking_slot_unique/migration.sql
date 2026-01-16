-- Prevent double-booking of the same bay/time for ACTIVE and PENDING_PAYMENT bookings
CREATE UNIQUE INDEX booking_slot_unique_active_pending
ON "Booking" ("bayId", "dateTime")
WHERE "status" IN ('ACTIVE', 'PENDING_PAYMENT');
