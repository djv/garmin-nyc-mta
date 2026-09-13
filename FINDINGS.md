# Findings

## Heading arrow layout — 2026-09-13

MtaBoardRenderer draws the arrow at w/2, h*0.12, with a 30-pixel shaft and proportionally enlarged arrowhead. Rotation and visibility behavior are unchanged. Agent-tested: FR965 production compilation and git diff --check pass. SDK display metadata confirms a 454 by 454 round screen; arrow geometry fits within the top region at all rotations. Simulator visual inspection passed for all eight compass directions and null-heading visibility using a temporary fixture outside the repository. All 10 simulator tests passed (0 failures/errors; MonkeyDo exits 1 despite PASSED). Contact sheet: /tmp/mta-arrow-sim-contact.png. Physical-watch installation was not performed. Rollback: restore the prior arrow coordinates and dimensions in source/MtaBoardRenderer.mc.

## Connect IQ upload — 2026-09-13

Signed build/NycMta.iq rebuilt successfully with export flag -e. SHA-256: 3e3c0238dd3732f099ae4c68f0f984a3f83d92c7aa70b6d11be95bde795b6736. Garmin sign-in cleared and user confirmed submission/agreement acceptance. Package and signature verified by Garmin; submitted version 0.3 with centered/enlarged arrow release notes. Listing https://apps.garmin.com/apps/0d372a47-1cd0-4f47-a826-b1230498bf3b now shows Version 0.3 (Internal: 3) and the new notes. It remains private BETA / App pending; displayed Latest Release still says September 11, 2026, so version/internal number and notes are the upload evidence. Not installed on physical watch.

## Nearest entrance — 2026-09-13

Proxy station.entrances is cached unchanged by BoardStore. StationCompass chooses the nearest valid coordinate locally; BoardView independently applies existing five-minute GPS and three-second heading validity. Missing entrances retain station bearing without distance; missing heading retains distance. No train-direction filtering, ranking or GPS-policy changes. Straight-line distances do not establish live entrance availability or platform access.

Agent-tested: 11 watch simulator tests (including nearest selection and old/new cache compatibility) pass; 31 proxy tests and public smoke/API checks pass. Eight heading renderings, missing heading, invalid-location display and no-entrance fallback were visually inspected with a temporary fixture. User requested no five-digit handling and stopped further simulator runs; final standard numeric label was compiled but not visually rechecked. Special font experiment removed. Production .prg and signed build/NycMta.iq built successfully. GitHub synchronized; no Garmin upload or physical installation. Proxy deployment and rollback evidence: /home/d/code/mta-proxy/FINDINGS.md; source comparison: /home/d/code/mta-proxy/data/README.md.
