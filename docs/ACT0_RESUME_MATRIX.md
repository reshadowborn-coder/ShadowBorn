# Act 0 resume matrix

Authoritative resume expectations:

| State | Resume location | Required invariant |
| --- | --- | --- |
| exterior | saved exterior checkpoint | completed encounters stay cleared |
| temple_entry | Temple | Shield Silver cannot duplicate |
| weapon_choice | Temple Covenant | membership persists |
| first_forge | Temple | selected weapon persists; Silver still present |
| catacombs / room 0 | Temple entry | forge is committed but Room 1 has not started |
| catacombs / rooms 1–5 | safe checkpoint before current room | cleared room index persists |
| room5_return | Temple Keeper route | no companion yet |
| room5_rematch | Temple Keeper route | companion + slot 2 persist; player walks back to the Catacombs |
| act0_complete | saved completion checkpoint | irreversible onboarding never replays |

Room 5 return and rematch use explicit deterministic checkpoints rather than the combat position that happened to be active at save time.
