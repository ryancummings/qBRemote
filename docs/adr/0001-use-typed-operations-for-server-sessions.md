# Use typed operations for server sessions

A server session accepts only operations defined in `QBOperation`.
Callers cannot supply arbitrary closures or use the session's authenticated service directly.

Each operation makes one API call.
When a request returns 401 or 403, the session can log in and retry that call once.
The retry does not repeat the caller's other work, such as refreshing a list or closing a sheet.

Each new network capability needs a `QBOperation` entry.
This extra step keeps login recovery in one place and makes the retry boundary clear.
