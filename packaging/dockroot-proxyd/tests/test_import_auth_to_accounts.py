import base64
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


PACKAGE_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = PACKAGE_ROOT / "scripts" / "import_auth_to_accounts.py"


def jwt_with_claims(claims):
    header = base64.urlsafe_b64encode(b'{"alg":"none","typ":"JWT"}').rstrip(b"=")
    payload = base64.urlsafe_b64encode(
        json.dumps(claims, separators=(",", ":")).encode("utf-8")
    ).rstrip(b"=")
    return f"{header.decode('ascii')}.{payload.decode('ascii')}.signature"


class ImportAuthToAccountsTests(unittest.TestCase):
    maxDiff = None

    def run_helper(self, auth_json, *extra_args):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            input_path = tmpdir_path / "auth.json"
            output_path = tmpdir_path / "accounts.json"
            input_path.write_text(
                json.dumps(auth_json, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            command = [
                sys.executable,
                str(SCRIPT_PATH),
                "--input",
                str(input_path),
                "--output",
                str(output_path),
                *extra_args,
            ]
            completed = subprocess.run(
                command,
                capture_output=True,
                text=True,
                check=False,
            )
            parsed_output = None
            if output_path.exists():
                parsed_output = json.loads(output_path.read_text(encoding="utf-8"))
            return completed, parsed_output

    def test_converts_portable_auth_json_to_accounts_store(self):
        id_token = jwt_with_claims(
            {
                "sub": "user-123",
                "email": "router@example.com",
                "https://api.openai.com/auth": {
                    "chatgpt_account_id": "account-123",
                    "chatgpt_plan_type": "team",
                },
            }
        )
        auth_json = {
            "auth_mode": "chatgpt",
            "last_refresh": "2026-04-11T00:00:00Z",
            "tokens": {
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "id_token": id_token,
            },
        }

        completed, accounts = self.run_helper(auth_json)

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(accounts["version"], 1)
        self.assertEqual(accounts["settings"], {})
        self.assertEqual(len(accounts["accounts"]), 1)
        self.assertEqual(accounts["accounts"][0]["label"], "router@example.com")
        self.assertEqual(accounts["accounts"][0]["principalId"], "router@example.com")
        self.assertEqual(accounts["accounts"][0]["accountId"], "account-123")
        self.assertEqual(accounts["accounts"][0]["planType"], "team")
        self.assertEqual(
            accounts["accounts"][0]["authJson"]["tokens"]["access_token"], "access-token"
        )

    def test_normalizes_legacy_flat_auth_shape(self):
        id_token = jwt_with_claims(
            {
                "sub": "legacy-user",
                "https://api.openai.com/auth": {
                    "chatgpt_account_id": "account-flat",
                },
            }
        )
        auth_json = {
            "access_token": "flat-access",
            "refresh_token": "flat-refresh",
            "id_token": id_token,
            "account_id": "account-flat",
        }

        completed, accounts = self.run_helper(auth_json, "--label", "Flat Import")

        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(accounts["accounts"][0]["label"], "Flat Import")
        self.assertEqual(accounts["accounts"][0]["accountId"], "account-flat")
        self.assertEqual(accounts["accounts"][0]["authJson"]["auth_mode"], "chatgpt")
        self.assertEqual(
            accounts["accounts"][0]["authJson"]["tokens"]["refresh_token"],
            "flat-refresh",
        )
        self.assertEqual(
            accounts["accounts"][0]["authJson"]["tokens"]["account_id"],
            "account-flat",
        )

    def test_rejects_missing_portable_tokens(self):
        completed, accounts = self.run_helper({"auth_mode": "chatgpt"})

        self.assertNotEqual(completed.returncode, 0)
        self.assertIsNone(accounts)
        self.assertIn("not portable", completed.stderr.lower())
        self.assertIn("access_token", completed.stderr)

    def test_requires_chatgpt_account_id(self):
        id_token = jwt_with_claims({"sub": "user-without-account"})
        auth_json = {
            "auth_mode": "chatgpt",
            "tokens": {
                "access_token": "access-token",
                "refresh_token": "refresh-token",
                "id_token": id_token,
            },
        }

        completed, accounts = self.run_helper(auth_json)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIsNone(accounts)
        self.assertIn("chatgpt_account_id", completed.stderr)


if __name__ == "__main__":
    unittest.main()
