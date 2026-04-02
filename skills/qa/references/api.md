# API Testing

Verify API endpoints return correct responses and explore beyond the spec for edge cases.

## Workflow

```
1. Discover     Find endpoints from spec, routes, OpenAPI, or diff
2. Authenticate Obtain tokens or session cookies
3. Verify       Test each endpoint against spec criteria
4. Explore      Beyond-spec testing on diff-affected endpoints
5. Document     Save evidence and write findings
```

## Setup

### Discover endpoints

```bash
# From the diff
git diff main...HEAD --name-only | grep -E '(route|controller|handler|api|endpoint)'

# From OpenAPI/Swagger
curl -sf http://localhost:<port>/api-docs | jq '.paths | keys[]'
curl -sf http://localhost:<port>/openapi.json | jq '.paths | keys[]'

# Common discovery endpoints
curl -sf http://localhost:<port>/api/
curl -sf http://localhost:<port>/swagger.json
```

### Authenticate

Detect the auth method from the spec, code, or .env and use the
matching pattern:

#### Bearer token (JWT / session token)

```bash
# Login and capture token
TOKEN=$(curl -sf -X POST http://localhost:<port>/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"password"}' \
  | jq -r '.token // .access_token // .jwt')

echo "Token: $TOKEN"

# Use token in subsequent requests
curl -sf http://localhost:<port>/api/resource \
  -H "Authorization: Bearer $TOKEN"
```

#### Cookie-based auth

```bash
curl -sf -c cookies.txt -X POST http://localhost:<port>/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"password"}'

# Use cookies in subsequent requests
curl -sf -b cookies.txt http://localhost:<port>/api/resource
```

#### API key

```bash
# API key in header (most common)
curl -sf http://localhost:<port>/api/resource \
  -H "X-API-Key: <key>"

# API key in Authorization header
curl -sf http://localhost:<port>/api/resource \
  -H "Authorization: ApiKey <key>"

# API key in query parameter
curl -sf "http://localhost:<port>/api/resource?api_key=<key>"
```

#### Basic auth

```bash
curl -sf -u "username:password" http://localhost:<port>/api/resource

# Or manually with base64
curl -sf http://localhost:<port>/api/resource \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)"
```

#### OAuth2 with refresh token

```bash
# Exchange refresh token for access token
TOKEN=$(curl -sf -X POST http://localhost:<port>/oauth/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=refresh_token&refresh_token=<refresh_token>&client_id=<client_id>&client_secret=<client_secret>' \
  | jq -r '.access_token')

# Use access token
curl -sf http://localhost:<port>/api/resource \
  -H "Authorization: Bearer $TOKEN"

# Test token refresh: use an expired token, expect 401, then refresh
EXPIRED="eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjB9.invalid"
STATUS=$(curl -sf -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $EXPIRED" \
  http://localhost:<port>/api/resource)
echo "Expired token status: $STATUS"  # Expected: 401
```

## Request Patterns

### GET

```bash
curl -sf -w '\n%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:<port>/api/resource
```

### POST (JSON)

```bash
curl -sf -w '\n%{http_code}' -X POST \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"test","value":123}' \
  http://localhost:<port>/api/resource
```

### PUT / PATCH

```bash
curl -sf -w '\n%{http_code}' -X PUT \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"updated"}' \
  http://localhost:<port>/api/resource/<id>

curl -sf -w '\n%{http_code}' -X PATCH \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"patched"}' \
  http://localhost:<port>/api/resource/<id>
```

### DELETE

```bash
curl -sf -w '\n%{http_code}' -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:<port>/api/resource/<id>
```

### File Upload (multipart)

```bash
curl -sf -w '\n%{http_code}' -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/file.pdf" \
  -F "description=test upload" \
  http://localhost:<port>/api/upload
```

### GraphQL

```bash
# Query
curl -sf -w '\n%{http_code}' -X POST \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"{ users { id name email } }"}' \
  http://localhost:<port>/graphql

# Mutation
curl -sf -w '\n%{http_code}' -X POST \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"mutation { createUser(input: {name: \"test\", email: \"test@example.com\"}) { id } }"}' \
  http://localhost:<port>/graphql

# With variables
curl -sf -w '\n%{http_code}' -X POST \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"mutation CreateUser($input: CreateUserInput!) { createUser(input: $input) { id } }","variables":{"input":{"name":"test","email":"test@example.com"}}}' \
  http://localhost:<port>/graphql
```

### Server-Sent Events (SSE)

```bash
# Connect and capture events (timeout after 10s)
timeout 10 curl -sf -N \
  -H 'Accept: text/event-stream' \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:<port>/api/stream \
  > <qa_dir>/api-sse-output.txt 2>&1

# Verify SSE format: each event should have "data:" prefix
cat <qa_dir>/api-sse-output.txt

# Check content type is text/event-stream
curl -sf -o /dev/null -w '%{content_type}' \
  -H 'Accept: text/event-stream' \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:<port>/api/stream
# Expected: text/event-stream
```

SSE format verification:
- Each event has `data: ...` line(s) followed by a blank line
- Optional `event:`, `id:`, `retry:` fields
- Connection should stay open until server closes or client disconnects
- Test: disconnect mid-stream, reconnect — does `Last-Event-ID` resume correctly?

### Streaming / chunked responses

```bash
# Capture a streaming response (common for AI/LLM endpoints)
timeout 30 curl -sf -N -X POST \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"prompt":"hello","stream":true}' \
  http://localhost:<port>/api/chat \
  > <qa_dir>/api-stream-output.txt 2>&1

# Verify transfer encoding
curl -sf -o /dev/null -D - \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:<port>/api/stream \
  | grep -i 'transfer-encoding'
# Expected: transfer-encoding: chunked

# Test early disconnect — server should not crash
timeout 1 curl -sf -N \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:<port>/api/stream > /dev/null 2>&1
# Then verify server is still healthy
curl -sf -w '%{http_code}' http://localhost:<port>/health
```

### Long-polling

```bash
# Long-poll with timeout
timeout 30 curl -sf -w '\n%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "http://localhost:<port>/api/events?timeout=25"

# Test: what happens when the poll times out with no events?
# Expected: 200 with empty array or 204 No Content, NOT a 5xx
```

## Response Verification

Always verify response **body content**, not just status code. Status code alone = L2 evidence. Body verification = L1 evidence.

### Parse JSON responses with jq

```bash
# Check specific field exists and has expected value
curl -sf http://localhost:<port>/api/resource/1 \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.name'

# Verify required fields are present
curl -sf http://localhost:<port>/api/resource/1 \
  -H "Authorization: Bearer $TOKEN" \
  | jq 'has("id", "name", "email", "created_at")'

# Check array length
curl -sf http://localhost:<port>/api/resources \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.data | length'

# Verify field types
curl -sf http://localhost:<port>/api/resource/1 \
  -H "Authorization: Bearer $TOKEN" \
  | jq '{id_is_number: (.id | type == "number"), name_is_string: (.name | type == "string")}'

# Check error response format
curl -sf http://localhost:<port>/api/resource/999 \
  -H "Authorization: Bearer $TOKEN" \
  | jq '{has_error: has("error"), has_message: has("message")}'
```

### Parse XML responses

```bash
# Check if xmllint is available
which xmllint && echo "available" || echo "not available — install libxml2"

# Verify well-formed XML
curl -sf http://localhost:<port>/api/resource.xml \
  -H "Authorization: Bearer $TOKEN" \
  | xmllint --format -

# Extract specific element
curl -sf http://localhost:<port>/api/resource.xml \
  -H "Authorization: Bearer $TOKEN" \
  | xmllint --xpath '//name/text()' -

# If xmllint not available, use grep for basic checks
curl -sf http://localhost:<port>/api/resource.xml \
  -H "Authorization: Bearer $TOKEN" \
  | grep -o '<name>[^<]*</name>'
```

### Verify plain text / CSV responses

```bash
# Plain text — check content type and body
CONTENT_TYPE=$(curl -sf -o /dev/null -w '%{content_type}' \
  http://localhost:<port>/api/export.txt)
echo "Content-Type: $CONTENT_TYPE"

# CSV — check header row and data
curl -sf http://localhost:<port>/api/export.csv \
  -H "Authorization: Bearer $TOKEN" \
  | head -5

# Verify CSV has expected columns
curl -sf http://localhost:<port>/api/export.csv \
  -H "Authorization: Bearer $TOKEN" \
  | head -1
# Expected: id,name,email,created_at
```

### Verify status codes

```bash
# Capture status code separately
STATUS=$(curl -sf -o /dev/null -w '%{http_code}' \
  http://localhost:<port>/api/resource)
echo "Status: $STATUS"

# Capture both body and status
RESPONSE=$(curl -sf -w '\n%{http_code}' \
  http://localhost:<port>/api/resource)
BODY=$(echo "$RESPONSE" | head -n -1)
STATUS=$(echo "$RESPONSE" | tail -1)
echo "Status: $STATUS"
echo "Body: $BODY"
```

## Functional Verification

### What to check per endpoint

1. **Happy path** — correct request → expected response body and status
2. **Response schema** — all required fields present, correct types
3. **Error responses** — invalid input → proper error format and status
4. **Auth** — no token → 401, wrong role → 403, expired token → 401
5. **Edge cases** — empty body, missing fields, extra fields

### CRUD end-to-end flow

Test the full lifecycle of a resource:

```bash
# 1. CREATE
CREATED=$(curl -sf -X POST \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"test-item","value":42}' \
  http://localhost:<port>/api/resource)
ID=$(echo "$CREATED" | jq -r '.id')
echo "Created ID: $ID"

# 2. READ — verify it exists
curl -sf http://localhost:<port>/api/resource/$ID \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.name'
# Expected: "test-item"

# 3. UPDATE
curl -sf -X PUT \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"updated-item","value":99}' \
  http://localhost:<port>/api/resource/$ID

# 4. READ — verify update applied
curl -sf http://localhost:<port>/api/resource/$ID \
  -H "Authorization: Bearer $TOKEN" \
  | jq '{name, value}'
# Expected: {"name": "updated-item", "value": 99}

# 5. DELETE
curl -sf -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:<port>/api/resource/$ID

# 6. READ — verify it's gone
STATUS=$(curl -sf -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:<port>/api/resource/$ID)
echo "Status after delete: $STATUS"
# Expected: 404
```

## WebSocket Verification

### Server-side handshake (curl)

```bash
curl -sf -o /dev/null -w '%{http_code}' \
  -H 'Upgrade: websocket' \
  -H 'Connection: Upgrade' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Version: 13' \
  http://localhost:<port>/<ws-path>
```

- 101 → PASS (Switching Protocols)
- 400/426 → FAIL (rejected upgrade)
- 404 → FAIL (route not found)
- Connection refused → service not running

### Client-side (browser)

Use the browser tools (see `references/browser.md`) to check WebSocket
connections from the browser side.

## Exploratory Testing

Beyond-spec exploration of API endpoints. Focus on areas touched by
the diff.

### What to explore

1. **Undocumented behavior** — unexpected content types, extra fields, null values
2. **Boundary values** — max length strings, 0, negative numbers, empty arrays
3. **Ordering and pagination** — large offsets, page size 0, negative page
4. **Rate limiting** — rapid repeated requests
5. **Cross-endpoint consistency** — create via POST, verify via GET, update via PUT, verify again
6. **Partial failures** — one field valid, another invalid
7. **Concurrent requests** — same resource modified simultaneously
8. **SQL injection** — `' OR 1=1 --`, `"; DROP TABLE` in string fields
9. **XSS in API responses** — `<script>alert(1)</script>` stored and returned
10. **Large payloads** — oversized request bodies, deeply nested JSON
11. **Streaming resilience** — early disconnect, reconnect with Last-Event-ID, very slow client
12. **Content negotiation** — Accept: application/xml vs application/json, unsupported types
13. **CORS** — requests from different origins, preflight OPTIONS handling

### Boundary value examples

```bash
# Empty string
curl -sf -X POST -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":""}' \
  http://localhost:<port>/api/resource

# Very long string
curl -sf -X POST -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"name\":\"$(python3 -c 'print("a"*10000)')\"}" \
  http://localhost:<port>/api/resource

# Null value
curl -sf -X POST -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":null}' \
  http://localhost:<port>/api/resource

# Zero and negative numbers
curl -sf -X POST -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"quantity":0}' \
  http://localhost:<port>/api/resource

curl -sf -X POST -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"quantity":-1}' \
  http://localhost:<port>/api/resource

# Wrong type
curl -sf -X POST -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"quantity":"not-a-number"}' \
  http://localhost:<port>/api/resource

# Extra unexpected fields
curl -sf -X POST -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"test","admin":true,"role":"superuser"}' \
  http://localhost:<port>/api/resource

# Deeply nested JSON
curl -sf -X POST -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"a":{"b":{"c":{"d":{"e":"deep"}}}}}' \
  http://localhost:<port>/api/resource

# Wrong content type
curl -sf -X POST \
  -H 'Content-Type: text/plain' \
  -H "Authorization: Bearer $TOKEN" \
  -d 'not json' \
  http://localhost:<port>/api/resource
```

### Pagination exploration

```bash
# Normal pagination
curl -sf "http://localhost:<port>/api/resources?page=1&limit=10" \
  -H "Authorization: Bearer $TOKEN" | jq '.data | length'

# Page 0
curl -sf -w '\n%{http_code}' "http://localhost:<port>/api/resources?page=0&limit=10" \
  -H "Authorization: Bearer $TOKEN"

# Negative page
curl -sf -w '\n%{http_code}' "http://localhost:<port>/api/resources?page=-1&limit=10" \
  -H "Authorization: Bearer $TOKEN"

# Very large page number
curl -sf -w '\n%{http_code}' "http://localhost:<port>/api/resources?page=999999&limit=10" \
  -H "Authorization: Bearer $TOKEN"

# Limit 0
curl -sf -w '\n%{http_code}' "http://localhost:<port>/api/resources?page=1&limit=0" \
  -H "Authorization: Bearer $TOKEN"

# Very large limit
curl -sf -w '\n%{http_code}' "http://localhost:<port>/api/resources?page=1&limit=999999" \
  -H "Authorization: Bearer $TOKEN"
```

## Evidence Collection

### Save full request/response

```bash
# Capture verbose output (request headers, response headers, body, status)
curl -sv -w '\n%{http_code}' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"test"}' \
  http://localhost:<port>/api/resource \
  > <qa_dir>/api-<test-name>.txt 2>&1
```

### Organize evidence files

```
<qa_dir>/
  api-auth-login.txt           — auth flow evidence
  api-create-resource.txt      — POST happy path
  api-get-resource.txt         — GET happy path
  api-crud-flow.txt            — full CRUD end-to-end
  api-boundary-empty.txt       — empty string input
  api-boundary-long.txt        — oversized input
  api-pagination-negative.txt  — negative page number
  api-report.md                — findings report
```

### Save evidence for each test

```bash
# Functional test with evidence
echo "=== TEST: Create resource ===" > <qa_dir>/api-create.txt
echo "Request: POST /api/resource" >> <qa_dir>/api-create.txt
echo "Body: {\"name\":\"test\"}" >> <qa_dir>/api-create.txt
echo "---" >> <qa_dir>/api-create.txt
curl -sv -w '\n%{http_code}' -X POST \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"test"}' \
  http://localhost:<port>/api/resource \
  >> <qa_dir>/api-create.txt 2>&1
```

## Guidance

- **Body over status.** Status code alone is L2 evidence. Always verify the response body contains the expected data. `200 OK` with an empty body or wrong data is still a bug.
- **Test the contract, not the implementation.** Verify what the API promises (spec, OpenAPI, types), not how it's built internally.
- **CRUD is the baseline.** For any resource endpoint, test the full create → read → update → delete → verify-deleted cycle before exploring edge cases.
- **Auth is a first-class concern.** Test every endpoint without auth (expect 401), with wrong role (expect 403), and with expired token. Don't assume auth works because one endpoint checks it.
- **Save evidence for every test.** Capture full request and response with `curl -sv`. A test without saved evidence cannot be L1.
- **Test error format consistency.** Every error response should follow the same format (e.g., `{"error": "message"}`). Inconsistent error formats are a real bug.
- **Check idempotency.** PUT and DELETE should be idempotent. Sending the same PUT twice should produce the same result. Deleting an already-deleted resource should return 404, not 500.
- **Verify side effects.** After a POST or PUT, do a GET to confirm the change persisted. After DELETE, confirm it's gone. Don't trust the write response alone.
- **Test with realistic data.** Use plausible names, emails, and values. Edge cases should test boundaries (empty, null, very long), not random gibberish.
- **Document each issue immediately.** Don't batch findings for later. Write each one as you find it.
- **Test every auth method the app supports.** If the app uses API keys AND Bearer tokens, test both. Test what happens when you mix them, or send both at once.
- **Streaming needs special attention.** SSE and chunked responses can't be verified with a single curl. Use `timeout` to bound the request, capture output to a file, then verify format and content after.
- **Check CORS headers.** If the API is consumed by a browser frontend, verify `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, and preflight `OPTIONS` responses.
- **Verify content types.** The response `Content-Type` header should match the actual body. JSON body with `text/html` content type is a bug.

## Issue Severity

Same definitions as `browser.md`:

| Severity | Definition |
|----------|------------|
| **critical** | Blocks a core workflow, causes data loss, or crashes the app |
| **high** | Major feature broken or unusable, no workaround |
| **medium** | Feature works but with noticeable problems, workaround exists |
| **low** | Minor cosmetic or polish issue |

## Output

Write findings to `<qa_dir>/api-report.md` using the
shared template in `references/report.md` (API section).
