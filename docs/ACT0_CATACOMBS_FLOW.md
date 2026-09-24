# Act 0 Catacombs progression

Rooms 1–4 are compact authored 1v1 checks. They reinforce target -> skill -> cooldown/state reading without introducing new meta systems.

Room 5 first entry is a deliberate solo-limit 1v2. It is not an RNG loss and must not be bypassable by grinding. On defeat:
- mark room5_solo_limit_seen;
- return player to Temple;
- Keeper/story handoff unlocks the first story summon and second team slot;
- room 5 becomes rematch-ready.

The rematch uses the same room and encounter identity so the player can directly feel the difference made by team composition. Clearing the rematch sets act0_complete.

Persistence keys: catacomb_room, room5_solo_limit_seen, story_summon_unlocked, room5_rematch_ready, act0_complete.
