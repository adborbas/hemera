#!/usr/bin/env python3
"""Performs the app's login exchange, so a broken server fails early, and prints the access token."""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


class NotReady(Exception):
    pass


class Rejected(Exception):
    pass


def request(url, data=None, headers=None):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers or {}), timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as error:
        raise Rejected(f"{url}: HTTP {error.code} {error.read().decode(errors='replace').strip()}") from error
    except (urllib.error.URLError, ConnectionError, TimeoutError) as error:
        raise NotReady(f"{url}: {error}") from error


def post_json(url, payload):
    return request(url, json.dumps(payload).encode(), {"Content-Type": "application/json"})


def log_in(base, username, password):
    # The same client_id and redirect_uri pair that OAuthFlowManager sends.
    client = {"client_id": base, "redirect_uri": f"{base}/hemera_callback"}
    flow = post_json(f"{base}/auth/login_flow", {**client, "handler": ["homeassistant", None], "type": "authorize"})
    step = post_json(f"{base}/auth/login_flow/{flow['flow_id']}",
                     {"client_id": base, "username": username, "password": password})
    if step.get("type") != "create_entry":
        raise Rejected(f"login was rejected: {json.dumps(step)}")
    form = urllib.parse.urlencode({"grant_type": "authorization_code", "code": step["result"], "client_id": base})
    return request(f"{base}/auth/token", form.encode(),
                   {"Content-Type": "application/x-www-form-urlencoded"})["access_token"]


def template_status(base, token):
    body = json.dumps({"template": "ok"}).encode()
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    try:
        with urllib.request.urlopen(urllib.request.Request(f"{base}/api/template", body, headers), timeout=30) as r:
            return r.status
    except urllib.error.HTTPError as error:
        return error.code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--username", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--version", required=True, help="the version Home Assistant must report")
    parser.add_argument("--pid", type=int, required=True, help="the Home Assistant process to watch")
    parser.add_argument("--template-status", type=int, required=True,
                        help="the admin-only /api/template status that proves the user's rights")
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()

    deadline = time.monotonic() + args.timeout
    reason = "nothing tried yet"
    while time.monotonic() < deadline:
        try:
            os.kill(args.pid, 0)
        except ProcessLookupError:
            sys.exit(f"Home Assistant exited during startup. Last error: {reason}")
        try:
            token = log_in(args.url, args.username, args.password)
            config = request(f"{args.url}/api/config", headers={"Authorization": f"Bearer {token}"})
            if config.get("recovery_mode"):
                sys.exit("Home Assistant started in recovery mode, so the fixture is broken")
            if config.get("state") == "RUNNING":
                if config["version"] != args.version:
                    sys.exit(f"Home Assistant reports {config['version']}, expected {args.version}")
                status = template_status(args.url, token)
                if status != args.template_status:
                    sys.exit(f"{args.username} got {status} from /api/template, expected {args.template_status}")
                print(token)
                return
            reason = f"Home Assistant is {config.get('state')}"
        except NotReady as error:
            reason = str(error)
        except Rejected as error:
            sys.exit(str(error))
        time.sleep(1)
    sys.exit(f"Home Assistant not ready after {args.timeout}s: {reason}")


if __name__ == "__main__":
    main()
