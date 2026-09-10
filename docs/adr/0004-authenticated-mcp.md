# MCP uses delegated OAuth access

For #321, expose a single Streamable HTTP MCP endpoint built on Ash AI, with OAuth authorization through `ash_authentication_oauth2_server`. All MCP tools, including discovery, require a signed-in person's delegated access so discovery can use their home search location and visibility rules and flow directly into an RSVP; OAuth discovery remains public, as does existing website browsing.

The initial writes are the person's own RSVPs, waitlist participation, and group memberships. Organizer management is deferred. Clients must obtain explicit user intent for writes, clarify ambiguous huddlz, and request separate consent to join a group or waitlist; OAuth connection consent does not authorize those individual choices. Standard MCP clients share the endpoint, with setup guidance for ChatGPT/Codex and Claude.
