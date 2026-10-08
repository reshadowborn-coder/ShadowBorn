# QA-23 side-on acceptance gate

Status: NOT ACCEPTED. This branch starts at QA-23 commit 7effc870; no merge is authorized.

1. Run Godot 4.7.2 tests on this exact branch SHA. Record commit, event, workflow ID and error logs.
2. Verify projected foot alignment, combat lane and camera frustum during IDLE, A1, A2 CONTACT_T0 and RECOVERY.
3. Capture separate native 1920x1080 and 2532x1170 frames. Reject resized 1280x720 captures and record renderer.
4. Check actual Shadow/Hound silhouette, sword contact and shipping HUD. Desktop GL is only a proxy.
5. Test on a physical iPhone 13 Pro with Metal, including frame pacing and thermal stability.

Research thresholds are provisional. Main and user-rated visual quality remain unchanged until acceptance evidence exists.

Provenance: original project requirements and source; no third-party assets or code.