# Contributing

Open an issue describing the problem before a large behaviour change. Keep the resource name `Wonkys_MoneyWash` consistent with its inventory export.

Run the checks in README.md, and explain which live FiveM scenarios you exercised. Prefer tests for financial decisions, ownership, locking, cancellation and failure recovery. Mocks are not a replacement for multiplayer testing.

Do not add streamed Bzzz assets, the laundromat MLO, credentials, database dumps or personal player information. Keep changes compatible with Qbox and the declared Ox dependencies. Document item/schema/configuration changes and avoid destructive migrations. Changes to fees, payout ownership or journal recovery require particular review.
