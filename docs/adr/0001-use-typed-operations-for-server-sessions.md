# Use typed operations for server sessions

Server sessions execute a closed `QBOperation` catalog instead of exposing an authenticated adapter or accepting arbitrary closures. Each operation contains one API call, so authentication recovery can replay it without repeating caller-owned side effects. Each new capability requires a catalog entry; that explicit interface growth is the accepted cost of safe replay and centralized authentication.
