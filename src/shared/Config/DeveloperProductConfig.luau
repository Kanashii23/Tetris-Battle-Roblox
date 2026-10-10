-- Existing project has no receipt processor. Do not enable purchases until a
-- server-verified, idempotent ProcessReceipt integration exists. UI grants nothing.
return {PurchasesEnabled=false,Cash={},Energy={}}
