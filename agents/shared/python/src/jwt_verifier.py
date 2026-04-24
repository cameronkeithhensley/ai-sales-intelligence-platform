"""Cognito JWT verification.

Fetches the user pool's JWKS lazily, caches it per process, and verifies
signature + issuer + audience + expiration. Rotation is handled by
honoring the `kid` claim: a token signed by a key the cache does not
know about triggers a single re-fetch.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

import httpx
from jose import jwk, jwt
from jose.exceptions import JWTError
from jose.utils import base64url_decode


@dataclass(frozen=True)
class Claims:
    sub: str
    email: str | None
    raw: dict[str, Any]


class JwtVerifier:
    """Cognito access-token verifier.

    Build once at service startup and reuse across requests.
    """

    def __init__(
        self,
        *,
        user_pool_id: str,
        region: str,
        client_id: str | None = None,
        token_use: str = "access",
        http_client: httpx.Client | None = None,
    ) -> None:
        self._user_pool_id = user_pool_id
        self._region = region
        self._client_id = client_id
        self._token_use = token_use
        self._http = http_client or httpx.Client(timeout=5.0)
        self._issuer = f"https://cognito-idp.{region}.amazonaws.com/{user_pool_id}"
        self._jwks_url = f"{self._issuer}/.well-known/jwks.json"
        self._jwks_by_kid: dict[str, Any] = {}
        self._jwks_fetched_at: float = 0.0

    def _refresh_jwks(self) -> None:
        resp = self._http.get(self._jwks_url)
        resp.raise_for_status()
        keys = resp.json().get("keys", [])
        self._jwks_by_kid = {k["kid"]: k for k in keys}
        self._jwks_fetched_at = time.time()

    def _get_jwk(self, kid: str) -> Any:
        if kid not in self._jwks_by_kid:
            # Unknown kid -> single refresh, then give up.
            self._refresh_jwks()
        if kid not in self._jwks_by_kid:
            raise JWTError(f"Unknown kid: {kid}")
        return self._jwks_by_kid[kid]

    def verify(self, token: str) -> Claims:
        """Verify signature + claims and return the decoded payload.

        Raises JWTError on any failure.
        """

        headers = jwt.get_unverified_headers(token)
        kid = headers.get("kid")
        if not kid:
            raise JWTError("Missing kid")

        key_data = self._get_jwk(kid)
        public_key = jwk.construct(key_data)

        message, encoded_sig = token.rsplit(".", 1)
        decoded_sig = base64url_decode(encoded_sig.encode("utf-8"))
        if not public_key.verify(message.encode("utf-8"), decoded_sig):
            raise JWTError("Bad signature")

        claims = jwt.get_unverified_claims(token)
        now = time.time()
        if claims.get("exp", 0) < now:
            raise JWTError("Token expired")
        if claims.get("iss") != self._issuer:
            raise JWTError("Bad issuer")
        if claims.get("token_use") != self._token_use:
            raise JWTError(f"Expected token_use={self._token_use}")
        if self._client_id is not None:
            # Access tokens carry the app client id in `client_id`, id
            # tokens in `aud`.
            expected_audience_fields = ("client_id", "aud")
            if not any(claims.get(f) == self._client_id for f in expected_audience_fields):
                raise JWTError("Bad audience")

        return Claims(
            sub=claims["sub"],
            email=claims.get("email"),
            raw=claims,
        )
