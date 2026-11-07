#!/usr/bin/env python3
"""Publish Vodya to GitHub using the credential git already stores.

Creates the repository if it does not exist, pushes `main`, then creates a
release and uploads the zip produced by tools/release.sh. Tokens are read from
the git credential helper, used in memory, and never printed.
"""
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

REPO = "vodya"
DESCRIPTION = "A floating Now Playing card for macOS with presets, custom artwork and an edge light."
TAG = "v1.1.0"
VERSION = TAG.lstrip("v")
ASSETS = [
    f"dist/Vodya-{VERSION}-universal.zip",
    f"dist/Vodya-{VERSION}-universal.zip.sha256",
]
NOTES = (
    "First public build: presets, custom artwork (any background image, PNG "
    "character), an edge light, and transport that works with Spotify. "
    "Universal binary for Apple silicon and Intel."
)


def stored_credential():
    out = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        capture_output=True,
        text=True,
    ).stdout
    fields = dict(line.split("=", 1) for line in out.splitlines() if "=" in line)
    return fields.get("password") or None


def api(path, method="GET", token=None, payload=None, base="https://api.github.com"):
    request = urllib.request.Request(base + path, method=method)
    request.add_header("Accept", "application/vnd.github+json")
    request.add_header("User-Agent", "vodya-publish")
    body = None
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    if payload is not None:
        body = json.dumps(payload).encode()
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, body, timeout=90) as response:
            return response.status, json.loads(response.read().decode() or "{}")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read().decode() or "{}")


def main() -> int:
    token = stored_credential()
    if not token:
        print("No github.com credential found in the git credential helper.")
        return 1

    status, me = api("/user", token=token)
    if status != 200:
        print(f"Stored credential was rejected ({status}).")
        return 1
    login = me["login"]
    print(f"signed in as {login}")

    status, repo = api(f"/repos/{login}/{REPO}", token=token)
    if status == 404:
        status, repo = api(
            "/user/repos",
            "POST",
            token=token,
            payload={"name": REPO, "description": DESCRIPTION, "private": False},
        )
        if status not in (200, 201):
            print(f"Could not create the repository ({status}): {repo.get('message')}")
            return 1
        print("created repository")
    print("repo:", repo["html_url"])

    subprocess.run(["git", "remote", "remove", "origin"], capture_output=True)
    subprocess.run(["git", "remote", "add", "origin", repo["clone_url"]], check=True)
    push = subprocess.run(
        ["git", "push", "-u", "origin", "main"],
        env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
    )
    if push.returncode != 0:
        print("Push failed.")
        return 1

    status, release = api(f"/repos/{login}/{REPO}/releases/tags/{TAG}", token=token)
    if status == 404:
        status, release = api(
            f"/repos/{login}/{REPO}/releases",
            "POST",
            token=token,
            payload={"tag_name": TAG, "name": f"Vodya {VERSION}", "body": NOTES},
        )
        if status not in (200, 201):
            print(f"Could not create the release ({status}): {release.get('message')}")
            return 1
        print("created release")
    print("release:", release.get("html_url"))

    upload_url = release.get("upload_url", "").split("{")[0]
    existing = {asset["name"] for asset in release.get("assets", [])}
    for path in ASSETS:
        name = os.path.basename(path)
        if name in existing:
            print("asset already attached:", name)
            continue
        if not os.path.exists(path):
            print("missing local asset:", path)
            continue
        with open(path, "rb") as handle:
            data = handle.read()
        request = urllib.request.Request(f"{upload_url}?name={name}", data=data, method="POST")
        request.add_header("Authorization", f"Bearer {token}")
        request.add_header("Content-Type", "application/octet-stream")
        request.add_header("User-Agent", "vodya-publish")
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                print("uploaded", name, response.status)
        except urllib.error.HTTPError as error:
            print("upload failed", name, error.code, error.read().decode()[:200])
            return 1

    print("published:", repo["html_url"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
