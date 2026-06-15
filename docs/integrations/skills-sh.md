# skills.sh Integration

SkillDeck uses skills.sh as a discovery index, not as an install authority.

## Search

The MVP calls the public search endpoint:

```text
GET https://skills.sh/api/search?q=<query>&limit=<n>
```

The response provides skill IDs, names, install counts, and `owner/repo` sources.
`SkillsShSearchProvider` decodes these into `SkillSummary` values for ranking and display.

The authenticated `/api/v1/*` endpoints require Vercel OIDC and are **not** used by the MVP.
There is no backend proxy.

## Trending

The Discover screen loads the skills.sh trending leaderboard on first appearance, before the
user searches. skills.sh exposes **no public JSON API** for trending; its `/trending` page is
rendered with Next.js React Server Components. `SkillsShTrendingProvider` requests the RSC
payload:

```text
GET https://www.skills.sh/trending?_rsc=1   (header: RSC: 1)
```

It extracts the embedded skill objects — which share the search response shape
(`source`, `skillId`, `name`, `installs`) — dedupes by `source/skillId`, sorts by install
count descending, and maps them into `SkillSummary` values.

This format is **undocumented and unstable**. If the RSC layout changes, parsing yields an
empty list (no crash); the user can still search. Non-200 responses surface as
`sourceUnavailable`.

## Install content

Install and preview content comes from public GitHub repositories resolved from search
results or user-added sources:

1. Resolve `owner/repo` (optionally `#ref`) via `GitHubURLParser`.
2. Fetch the recursive git tree (`api.github.com/.../git/trees/<ref>?recursive=1`).
3. Download each `SKILL.md`/`README.md` blob from `raw.githubusercontent.com`.
4. Derive a content hash and record the tree SHA as the source commit.

GitHub requests send a `User-Agent` (required by the API) and treat HTTP 403 as a
rate-limit signal.

## Degraded mode

If skills.sh search is unavailable, the app still supports adding public GitHub sources
directly by URL.

## Known limitations (MVP)

- Per-file raw downloads make scanning very large monorepos slow; a future version can
  fetch a repository tarball once instead.
- The git tree API can be truncated for very large repositories; truncated trees are not
  yet paged.
