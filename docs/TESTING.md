# Live acceptance checklist

Use test funds and two characters on a development server. Passing mocks does not establish that these scenarios work in a real FiveM session.

- [ ] Place attendant and Bzzz washer on the MLO floor; check heading, collision and target alignment.
- [ ] Confirm original MLO washers have no targets and the four dryers remain selectable.
- [ ] Receive tablet from NPC; open from inventory; check logo, UI fit and Escape cleanup.
- [ ] Select a pair and confirm one rental fee; double-click payment and try simultaneous bookings from two players.
- [ ] Check insufficient cash, no inventory space and a missing tablet definition produce useful failures.
- [ ] Load minimum/maximum dirty batches; confirm full-to-empty bag animation, hand attachment and machine animation.
- [ ] Cancel each loading/unloading step; confirm no transfer and no leftover props or stuck busy state.
- [ ] Attempt early collection and another character's machine/bundle; confirm rejection.
- [ ] Collect wet bundle, load the assigned dryer and receive the correct clean payout exactly once.
- [ ] Try an unassigned/rented dryer, full inventory during collection and moving machines during a rental.
- [ ] Reconnect and restart only the script while washing, holding wet cash and drying; confirm ownership/timers.
- [ ] Check what the second player sees: washer animation and the intentionally local bag-prop limitation.
- [ ] End an unused rental without refund; confirm active or journal-blocked rentals cannot be discarded.
- [ ] Verify no map blip, duplicate NPC, duplicate prop or lingering tablet after closing/stopping.

Do not deliberately crash a live server to test financial recovery. Review pending/loading/claiming reconciliation on a backed-up development database with known records and sanitised logs.
