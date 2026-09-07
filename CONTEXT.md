# qBittorrent Remote

This glossary describes saved qBittorrent servers, access to them, and local torrent browsing.

## Language

**Server profile**:
A saved server address, account name, and connection preferences. Its credentials belong to that profile.
_Avoid_: Server session, connection

**Server session**:
Access to exactly one saved server profile, including its authentication state.
_Avoid_: Connection, client

**Connection status**:
The observed state of a server session: connecting, connected, or failed.
_Avoid_: Session, server state

**Server profile draft**:
Unsaved values for a new or existing server profile. Testing them leaves the saved profile and credentials unchanged.
_Avoid_: Temporary profile, form state

**Torrent browsing**:
The local view of the current torrents after search, filters, and sorting. It does not include fetching, polling, or torrent actions.
_Avoid_: Torrent list, filtering
