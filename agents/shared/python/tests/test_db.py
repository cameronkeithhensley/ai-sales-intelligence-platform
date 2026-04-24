import pytest

import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
from db import validate_ident  # noqa: E402


class TestValidateIdent:
    def test_accepts_valid_lowercase_identifier(self):
        assert validate_ident("tenant_abc123") == "tenant_abc123"

    def test_accepts_single_letter(self):
        assert validate_ident("t") == "t"

    def test_rejects_leading_digit(self):
        with pytest.raises(ValueError, match="Invalid SQL identifier"):
            validate_ident("1bad")

    def test_rejects_uppercase(self):
        with pytest.raises(ValueError, match="Invalid SQL identifier"):
            validate_ident("Tenant")

    @pytest.mark.parametrize(
        "bad_input",
        [
            'x"; DROP TABLE users; --',
            "tenant; DROP",
            "tenant-abc",
            "",
            "tenant abc",
        ],
    )
    def test_rejects_injection_patterns(self, bad_input):
        with pytest.raises(ValueError, match="Invalid SQL identifier"):
            validate_ident(bad_input)

    @pytest.mark.parametrize("bad_input", [None, 42, 3.14, ["t"], {"x": "y"}])
    def test_rejects_non_string(self, bad_input):
        with pytest.raises(ValueError, match="Invalid SQL identifier"):
            validate_ident(bad_input)

    def test_rejects_over_63_chars(self):
        with pytest.raises(ValueError, match="Invalid SQL identifier"):
            validate_ident("a" * 64)
