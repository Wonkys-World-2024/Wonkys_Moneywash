# Administrator guide

## Installation and diagnostics

Follow README.md for dependencies, SQL and item definitions. Always keep the installed resource name `Wonkys_MoneyWash`, including capitalization, because the inventory item references its export.

Server console:

```text
restart Wonkys_MoneyWash
washbuild
washbzzzallow SERVER_ID
```

`washbuild` prints the actual loaded resource directory, version and whether tablet.lua exists/is listed in the manifest. If it reports an old version, replace the files at THAT directory. Do not nest a fresh resource inside an old copy. `washbzzzallow` grants placement to a character until disconnect or script restart, not to everybody. With only one player connected the ID can be omitted.

In-game chat commands use `/`; F8 commands do not:

| Chat command | Purpose |
| --- | --- |
| `/washcheck` | Main-client and tablet-readiness output |
| `/washdesk` | Place/move the attendant at your standing position and heading |
| `/washbzzz washer1` | Place/move a Bzzz washer at the nearby clear floor point under the camera |
| `/washbzzz washer1 90` | Place at floor point with an explicit heading |
| `/washreload` | Rebuild local target zones |
| `/laundry` | Open nearest enabled machine within reach |
| `/laundry dryer1` | Open a specific nearby enabled machine |
| `/washplace dryer dryer1` | Move a target to a camera ray hit; requires permanent placement ACE |

Active or rented machines cannot be moved. The four logical washer IDs are washer1–washer4; only placed Bzzz washers are enabled. The MLO's original washer geometry remains visible but has no interaction target.

If washcheck reports tablet NOT LOADED, capture the FIRST earlier SCRIPT ERROR in F8. If even washcheck is unknown, check washbuild and client startup errors before changing permissions.

## Tablet and attendant

The NPC location is stored in ww_laundry_settings. Its creation assumes a player standing coordinate and subtracts one metre for ped placement. Re-run washdesk if the floor/heading needs adjustment. There are intentionally no guessed public NPC coordinates.

The tablet requires the `ww_wash_tablet` item to be loaded by ox_inventory. Add its entry inside the item return table, copy its icon and restart the server. A generic inventory-capacity failure can also occur if the item definition is missing; check the definition as well as free slots and carry weight. The tablet weighs 500g.

The item is not consumed. A character at the desk or holding the tablet can open the rental UI; server checks still determine the character's own pair and charge. The tablet does not grant placement permission or bypass machine proximity.

## Assets and animation

Install Bzzz assets separately from their official source. Never duplicate their YTYP/resource. Do not hot-restart the Bzzz asset resource while its props are spawned. Restarting the script alone is supported.

The idle/running washer models use Bzzz's automatic rotating-money animation. Running state refreshes about every 2.5 seconds. Clients reconstruct local prop instances from saved placement and current server state; animation phase can differ between clients.

handling.lua uses Bzzz full/empty money bags for local cosmetic interactions. Config.BagHandling controls hand offsets, floor offsets and durations. Cancel each phase during testing. Local props are removed on cancellation, errors and resource stop; financial callbacks occur only after successful completion. Other players may see the replicated ped animation without its local bag. The original full door-opening/synchronised scene choreography is not implemented.

## Rentals and old batches

One customer owns one pair for a complete batch. The fee is separate from the payout cut. No automatic expiry or automatic refund occurs. Unused active reservations can be ended through the UI without refund. Once a batch is linked, finish it or ask staff to reconcile. Offline characters retain reservations.

Existing wet bundles from before rentals were introduced can be dried in an unreserved dryer. If a historical unplaced MLO washer still contains a batch, its target is intentionally hidden and placement refuses to overwrite it: staff must review that row before reusing the ID. Do not delete it merely to free a machine.

## Financial reconciliation

Read-only diagnostic queries:

```sql
SELECT * FROM ww_laundry_rentals WHERE state='pending';
SELECT * FROM ww_laundry_batches WHERE stage IN ('loading','claiming');
SELECT * FROM ww_laundry_rentals;
```

Qbox cash, ox_inventory and SQL have separate commits. During a crash, a pending rental may already have charged cash; a claiming batch may already have delivered a bundle or payout. A loading batch may or may not have consumed its input. Compare the character's inventory, Qbox money reason logs and SQL journal before making a correction. Never blindly reset claiming to drying or refund an ambiguous record. Back up the database before staff writes.

Normal washing/drying rows use wall-clock timestamps and continue across reconnects and script restarts. Inventory/cash persistence during a full server crash depends on framework save behaviour. Do not promise automatic crash-proof recovery.

## Configuration and data retention

Economy and bag settings live in config.lua. Machine/prop/attendant positions live in SQL. Retain the SQL tables on upgrades; CREATE IF NOT EXISTS is non-destructive. Paid batches remain an audit trail. Resolve abandoned rentals deliberately with the owning character or after staff review; no destructive reset command is supplied.

Do not export live tables, logs, server.cfg or player identifiers into the public repository. Only the clean schema and sample config belong there.
