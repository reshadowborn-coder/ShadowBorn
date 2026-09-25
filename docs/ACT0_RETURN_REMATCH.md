# Room 5 return/rematch state machine

First Room 5 contact is an authored solo-limit event. It commits the fact that the limit was seen before requesting a return to Temple.

Temple return state:
- Act0 stage = room5_return.
- Keeper is the only required progression interaction.
- Keeper unlocks the deterministic story companion and team slot 2.
- Unlock is persisted before the player can leave for the rematch.

Rematch state:
- Act0 stage = room5_rematch.
- Same Room 5 enemy identity.
- Shadow + story companion are active.
- Clearing Room 5 commits act0_complete and moves the Act0 stage to act0_complete.

Reload rules:
- Reload before solo-limit: no companion.
- Reload after solo-limit but before Keeper: return state remains.
- Reload after Keeper: companion and slot 2 remain unlocked; resume stays on the Temple Keeper route and the player walks back to the Catacombs.
- Reload after rematch: Act 0 remains complete and must not replay irreversible onboarding.
