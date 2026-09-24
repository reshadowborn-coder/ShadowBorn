# First Silver / first forge invariants

- New game starts with 0 Silver.
- The pre-Temple Shield Boss grants exactly 1 Silver on its first authoritative clear.
- Reload/re-entry cannot grant the reward again because cleared_encounters is the reward ledger.
- Covenant weapon choice does not spend Silver.
- First forge validates Covenant + weapon family + Silver >= 1.
- Forge transaction debits 1 Silver, creates the selected shadow weapon at +0, equips it, marks first_forge_done and advances to catacombs.
- The authoritative save is written only after the complete in-memory transaction, so no intermediate debit-only or item-without-equip state is intentionally persisted.
- A +0 item has no passive bonus. First equipment bonus remains a later +5 rule.
