# Security policy

## Supported version

The latest 1.4.x beta is the supported source version. It has no independent security audit or exploit-proof guarantee.

## Reporting

Use this repository's GitHub private vulnerability reporting feature if enabled. If it is unavailable, open an issue requesting a private contact without including exploit steps, sensitive logs, player data, credentials or live server addresses. Maintainers should enable private vulnerability reporting before promoting the repository publicly.

## Implemented controls

- Server-owned fees, payout ratios, batch amounts, item definitions and completion time.
- Character-bound wet bundles and per-batch validation; strict item metadata during removal.
- Machine proximity, type, Bzzz placement, rental assignment and owner checks.
- Per-character/machine locks across yielding operations; rental allocation lock and SQL unique constraints.
- Recheck character identity immediately before financial exports.
- Callback limit: 20 requests per callback per player in 10 seconds.
- ACE or console-only character-session placement authorisation.
- Parameterised SQL and textContent-based UI rendering.
- Pending/loading/claiming financial journals; no automatic ambiguous retries.
- Cosmetic bag/model animation never authorises a payout or takes player-supplied prices.

## Operational limits

Qbox cash, ox_inventory and SQL do not share one atomic transaction. A process crash may occur after one system commits but before another records success. Inspect pending rentals and loading/claiming batches alongside inventory and Qbox logs before staff reconciliation. Never automatically reset payout states or blindly refund. Actual inventory/cash persistence during a full server crash depends on framework save behaviour.

Offline or abandoned active batches keep their reservations. Staff must resolve them deliberately; they do not expire automatically. Client asset rendering is cosmetic and local, not authoritative. These controls assume trusted server resources, secured database access and correct dependency configuration.

Do not commit server.cfg, connection strings, txAdmin data, server keys, Discord webhook URLs, account identifiers, real database dumps or live log files. A sample configuration and CREATE-only schema are included instead.
