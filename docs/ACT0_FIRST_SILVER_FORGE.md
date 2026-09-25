# First Silver / first forge invariants

- New game starts with 0 Silver.
- The pre-Temple Shield Boss grants exactly 1 Silver on its first authoritative clear.
- Reload/re-entry cannot grant the reward again because cleared_encounters is the reward ledger.
- Covenant weapon choice does not spend Silver.
- First forge validates Covenant + weapon family + Silver >= 1.
- Forge transaction debits 1 Silver, creates the selected shadow weapon at +0, equips it, marks first_forge_done and advances the Act 0 stage to catacombs.
- `catacomb_room=0` remains valid immediately after forge: the lower route is unlocked, but Room 1 does not start until the player physically enters the Catacomb passage.
- The complete post-forge candidate snapshot is persisted before the live progression object is promoted. A crash therefore recovers to either the complete pre-forge state or the complete post-forge state; never a debit-only or item-without-equip state.
- A +0 item has no passive bonus. First equipment bonus remains a later +5 rule.
