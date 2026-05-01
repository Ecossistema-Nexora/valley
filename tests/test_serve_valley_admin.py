from pathlib import Path

from scripts.serve_valley_admin import ROOT, ValleyAdminHandler


def test_normalize_string_list_sanitizes_entries():
    payload = ["  Amazon  ", "", "   ", 123, "x" * 200]
    result = ValleyAdminHandler._normalize_string_list(payload, max_items=10, max_item_len=8)
    assert result == ["Amazon", "123", "xxxxxxxx"]


def test_is_allowed_local_feed_accepts_workspace_paths():
    candidate = ROOT / "admin" / "valley_admin_data.json"
    assert ValleyAdminHandler._is_allowed_local_feed(candidate)


def test_is_allowed_local_feed_rejects_outside_workspace():
    assert not ValleyAdminHandler._is_allowed_local_feed(Path("/etc/passwd"))


def test_private_host_blocks_localhost_and_private_ranges():
    assert ValleyAdminHandler._is_private_host("localhost")
    assert ValleyAdminHandler._is_private_host("127.0.0.1")
    # TEST-NET-3 (RFC 5737) is non-routable, should be blocked.
    assert ValleyAdminHandler._is_private_host("203.0.113.10")


def test_validate_feed_reference_rejects_outside_workspace_path():
    ok, message = ValleyAdminHandler._validate_feed_reference("/etc/passwd")
    assert not ok
    assert "fora do workspace" in message


def test_validate_feed_reference_rejects_missing_remote_host():
    ok, message = ValleyAdminHandler._validate_feed_reference("https:///feed.json")
    assert not ok
    assert "host remoto ausente" in message


def test_validate_feed_reference_accepts_supported_inputs():
    ok_remote, _ = ValleyAdminHandler._validate_feed_reference("https://example.com/feed.json")
    ok_local, _ = ValleyAdminHandler._validate_feed_reference("admin/valley_admin_data.json")
    assert ok_remote
    assert ok_local


def test_extract_keys_sample_handles_scalar_entries():
    assert ValleyAdminHandler._extract_keys_sample([1, 2, 3]) == []


def test_extract_keys_sample_uses_first_object_entry():
    sample = ValleyAdminHandler._extract_keys_sample(["x", {"sku": "A1", "qty": 5}, {"other": "ignored"}])
    assert sample == ["sku", "qty"]
