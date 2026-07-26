---
alwaysApply: true
description: Route OMP web extraction through a locally configured self-hosted Firecrawl MCP server.
---

# Web extraction via self-hosted Firecrawl

A `firecrawl` MCP server may be configured locally. Configure `FIRECRAWL_API_URL` only in local runtime data; never commit its value.

When a task needs web page extraction, scraping, or structured extraction from known URLs:

1. OMP v17 mounts MCP capabilities as `xd://` devices. Run `read xd://`, locate the Firecrawl device, and inspect its contract with `read xd://<device>` before invoking it.
2. Invoke the chosen device by writing the documented JSON payload to `xd://<device>`. For full-page reading, request markdown and `onlyMainContent: true` when those fields exist. Do not assume direct top-level `firecrawl_scrape` or `firecrawl_extract` tools are registered.
3. Keep `providers.webSearch: kagi` for ordinary web search unless the user asks to change search routing.
4. Use hosted Firecrawl only when the local endpoint is unavailable and the user approves the fallback.
