# STRIKE DUEL — playable multiplayer prototype

A two-player, first-person browser arena. Supports one mobile and one desktop player.

## Run locally
1. Install Node.js 18 or later.
2. Run `npm install` then `npm start`.
3. Visit `http://localhost:3000` on your computer.

## Play over the internet
Deploy the complete folder to a Node.js hosting service that supports persistent WebSocket connections and HTTPS (for example Render or Railway). Set start command to `npm start`. Share the HTTPS address with your friend. Player one leaves the room code empty, copies the generated six-character room code; player two enters that code. Both must use the same deployed server.

## Controls
Desktop: WASD, mouse to aim, click to shoot, R to reload, Shift to sprint. Mobile: left joystick, drag on right side to aim, FIRE and reload buttons.

## Important limitations
This is an initial prototype, not a CS2-quality release. Visuals are procedural low-poly 3D rather than photorealistic. Network gameplay works with a single Node server, but client movement and shot direction are not server-authoritative, and obstacles are not yet included in bullet hit testing. Not suitable for competitive or public deployment without anti-cheat, authoritative physics, rate limits, persistence, and additional testing. CDN access to Three.js is required. Room state is in memory; server restarts clear rooms.
