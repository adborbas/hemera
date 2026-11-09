#!/usr/bin/env python3
"""Waits until a user can read the seeded climate history for every range the app's charts ask for."""

import argparse
import asyncio
import sys
import time
from datetime import datetime, timedelta, timezone

import aiohttp

# The period and window of each range in Hemera/SensorHistory/SensorHistoryProviding.swift.
RANGES = {"24h": ("5minute", timedelta(days=1)), "7d": ("hour", timedelta(days=7)),
          "30d": ("hour", timedelta(days=30))}


async def empty_ranges(base, token, statistic_ids):
    """Names every range and statistic the user reads no means for."""
    now = datetime.now(timezone.utc)
    async with aiohttp.ClientSession() as session, session.ws_connect(f"{base}/api/websocket") as ws:
        await ws.receive_json()
        await ws.send_json({"type": "auth", "access_token": token})
        if (auth := await ws.receive_json())["type"] != "auth_ok":
            sys.exit(f"WebSocket login failed: {auth}")
        empty = []
        for number, (name, (period, window)) in enumerate(RANGES.items(), 1):
            await ws.send_json({"id": number, "type": "recorder/statistics_during_period",
                                "start_time": (now - window).isoformat(), "end_time": now.isoformat(),
                                "statistic_ids": statistic_ids, "period": period, "types": ["mean"]})
            reply = await ws.receive_json()
            if not reply["success"]:
                sys.exit(f"{name} history was refused: {reply['error']}")
            empty += [f"{name} {statistic_id}" for statistic_id in statistic_ids
                      if not reply["result"].get(statistic_id)]
        return empty


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--token", required=True)
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("statistic_ids", nargs="+")
    args = parser.parse_args()

    # The recorder writes the seed from its queue, so it can land after Home Assistant reports RUNNING.
    deadline = time.monotonic() + args.timeout
    while empty := asyncio.run(empty_ranges(args.url, args.token, args.statistic_ids)):
        if time.monotonic() > deadline:
            sys.exit(f"no history after {args.timeout}s for: {', '.join(empty)}")
        time.sleep(1)


if __name__ == "__main__":
    main()
