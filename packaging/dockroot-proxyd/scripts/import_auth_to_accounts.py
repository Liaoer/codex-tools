#!/usr/bin/env python3

import argparse
import base64
import json
import sys
import time
import uuid
from pathlib import Path


NON_PORTABLE_AUTH_ERROR = (
    "auth.json is not portable: missing embedded ChatGPT OAuth tokens "
    "(access_token / id_token). On newer Codex installations, especially on macOS, "
    "tokens may live in Keychain instead of auth.json. Run `codex login` on the target "
    "machine or export a full auth.json that includes access_token, id_token, and "
    "refresh_token."
)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Convert a portable Codex auth.json into a single-account accounts.json."
    )
    parser.add_argument("--input", required=True, help="Path to the source auth.json")
    parser.add_argument(
        "--output",
        required=True,
        help="Path to write accounts.json, or '-' to print the JSON to stdout",
    )
    parser.add_argument(
        "--label",
        help="Optional account label override. Defaults to email or a Codex short label.",
    )
    return parser.parse_args()


def load_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise ValueError(f"input file not found: {error.filename}") from error
    except json.JSONDecodeError as error:
        raise ValueError(f"input auth.json is not valid JSON: {error}") from error


def normalize_auth_json(auth_json):
    if not isinstance(auth_json, dict):
        raise ValueError("auth.json root must be a JSON object")

    tokens = auth_json.get("tokens")
    if isinstance(tokens, dict):
        return auth_json

    access_token = auth_json.get("access_token")
    id_token = auth_json.get("id_token")
    if access_token and id_token:
        normalized_tokens = {
            "access_token": access_token,
            "id_token": id_token,
        }
        if auth_json.get("refresh_token"):
            normalized_tokens["refresh_token"] = auth_json["refresh_token"]
        if auth_json.get("account_id"):
            normalized_tokens["account_id"] = auth_json["account_id"]

        normalized = {
            "auth_mode": auth_json.get("auth_mode", "chatgpt"),
            "tokens": normalized_tokens,
        }
        if "last_refresh" in auth_json:
            normalized["last_refresh"] = auth_json["last_refresh"]
        return normalized

    return auth_json


def decode_jwt_payload(token):
    try:
        payload = token.split(".")[1]
    except IndexError as error:
        raise ValueError("auth.json contains an invalid id_token") from error

    padded = payload + "=" * ((4 - len(payload) % 4) % 4)
    try:
        decoded = base64.urlsafe_b64decode(padded.encode("ascii"))
    except (ValueError, UnicodeEncodeError) as error:
        raise ValueError(f"failed to decode id_token payload: {error}") from error

    try:
        return json.loads(decoded.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"failed to parse id_token payload: {error}") from error


def extract_auth(auth_json):
    tokens = auth_json.get("tokens")
    if not isinstance(tokens, dict):
        auth_mode = str(auth_json.get("auth_mode", "")).strip().lower()
        if auth_mode and auth_mode not in {"chatgpt", "chatgpt_auth_tokens"}:
            raise ValueError(
                f"auth.json is not portable: auth_mode={auth_mode!r} is not a ChatGPT OAuth login"
            )
        raise ValueError(NON_PORTABLE_AUTH_ERROR)

    access_token = tokens.get("access_token")
    if not access_token:
        raise ValueError(
            "auth.json is not portable: missing access_token in auth.json tokens"
        )

    id_token = tokens.get("id_token")
    if not id_token:
        raise ValueError("auth.json is not portable: missing id_token in auth.json tokens")

    claims = decode_jwt_payload(id_token)
    auth_claim = claims.get("https://api.openai.com/auth")
    if not isinstance(auth_claim, dict):
        auth_claim = {}

    account_id = tokens.get("account_id") or auth_claim.get("chatgpt_account_id")
    if not account_id:
        raise ValueError("unable to extract chatgpt_account_id from auth.json")

    email = claims.get("email")
    plan_type = auth_claim.get("chatgpt_plan_type")
    principal_id = (
        normalize_principal(email)
        or normalize_principal(auth_claim.get("chatgpt_user_id"))
        or normalize_principal(auth_claim.get("user_id"))
        or normalize_principal(claims.get("sub"))
        or account_id
    )

    return {
        "access_token": access_token,
        "account_id": account_id,
        "email": email,
        "plan_type": plan_type,
        "principal_id": principal_id,
    }


def normalize_principal(value):
    if not isinstance(value, str):
        return None
    trimmed = value.strip()
    if not trimmed:
        return None
    if "@" in trimmed:
        return trimmed.lower()
    return trimmed


def default_label(email, account_id):
    if isinstance(email, str) and email.strip():
        return email.strip()
    return f"Codex {short_account(account_id)}"


def short_account(account_id):
    if len(account_id) <= 8:
        return account_id
    return account_id[:8]


def build_accounts_store(auth_json, label_override=None):
    normalized_auth = normalize_auth_json(auth_json)
    extracted = extract_auth(normalized_auth)
    now = int(time.time())

    return {
        "version": 1,
        "accounts": [
            {
                "id": str(uuid.uuid4()),
                "label": label_override or default_label(
                    extracted["email"], extracted["account_id"]
                ),
                "principalId": extracted["principal_id"],
                "email": extracted["email"],
                "accountId": extracted["account_id"],
                "planType": extracted["plan_type"],
                "authJson": normalized_auth,
                "addedAt": now,
                "updatedAt": now,
                "usage": None,
                "usageError": None,
                "authRefreshBlocked": False,
                "authRefreshError": None,
            }
        ],
        "settings": {},
    }


def write_output(store, output_path):
    serialized = json.dumps(store, ensure_ascii=False, indent=2)
    if output_path == "-":
        sys.stdout.write(serialized)
        sys.stdout.write("\n")
        return

    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(serialized + "\n", encoding="utf-8")


def main():
    args = parse_args()
    try:
        auth_json = load_json(args.input)
        store = build_accounts_store(auth_json, label_override=args.label)
        write_output(store, args.output)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
