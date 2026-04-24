"""Generic HTTP + HTML fetch/parse stub.

The production version dispatches per-source extractors which are
proprietary. This public version exposes a single `fetch(url, ...)`
function that performs a GET with a non-browser User-Agent, parses
the response into a BeautifulSoup tree, and returns the raw text +
the parsed soup. No domain-specific selectors, no hardcoded URLs,
no signal extraction.
"""

from __future__ import annotations

from dataclasses import dataclass

import httpx
from bs4 import BeautifulSoup
from tenacity import retry, stop_after_attempt, wait_exponential

DEFAULT_USER_AGENT = "ai-sip-scout/0.1 (+https://example.com/bot)"


@dataclass(frozen=True)
class FetchResult:
    url: str
    status_code: int
    text: str
    soup: BeautifulSoup


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=0.5, min=0.5, max=4.0),
    reraise=True,
)
def fetch(
    url: str,
    *,
    timeout: float = 10.0,
    user_agent: str = DEFAULT_USER_AGENT,
    client: httpx.Client | None = None,
) -> FetchResult:
    """Fetch a URL and return a FetchResult containing status, text, soup.

    Intentionally generic: no Accept-Language or cookie juggling, no
    header spoofing. Downstream per-source extractors (proprietary)
    compose their own behaviour on top of this primitive.
    """

    owns_client = client is None
    http = client or httpx.Client(timeout=timeout, headers={"User-Agent": user_agent})
    try:
        response = http.get(url)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "lxml")
        return FetchResult(
            url=url,
            status_code=response.status_code,
            text=response.text,
            soup=soup,
        )
    finally:
        if owns_client:
            http.close()
