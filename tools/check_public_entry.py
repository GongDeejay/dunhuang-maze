#!/usr/bin/env python3
"""Read-only public entry checks. No SSH, credentials, configuration writes or TLS bypass.

Usage: python3 tools/check_public_entry.py [--domain maze.mplusm.site]
Exit 1 means at least one entry did not pass; an available :8443 does not mask broken :443.
"""
import argparse
import json
import urllib.error
import urllib.parse
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def acceptable(kind, result, domain):
    if result.get("error"):
        return False
    headers = result["headers"]
    if kind == "http":
        destination = urllib.parse.urlsplit(headers.get("location", ""))
        return result["status"] in (301, 302, 307, 308) and destination.scheme == "https" and destination.hostname == domain
    return result["status"] == 200 and headers.get("cross-origin-opener-policy") == "same-origin" and headers.get("cross-origin-embedder-policy") == "require-corp"


def probe(opener, url, timeout):
    try:
        response = opener.open(urllib.request.Request(url, method="HEAD"), timeout=timeout)
    except urllib.error.HTTPError as error:
        response = error
    except (OSError, urllib.error.URLError) as error:
        return {"url": url, "error": str(error)}
    with response:
        return {"url": url, "status": response.status, "headers": {k.lower(): v for k, v in response.headers.items()}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--domain", default="maze.mplusm.site")
    parser.add_argument("--timeout", type=float, default=15)
    args = parser.parse_args()
    if any(c in args.domain for c in "/:@"):
        parser.error("--domain must be a hostname, without scheme, port or credentials")
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    results = []
    for kind, url in [("http", f"http://{args.domain}/"), ("https", f"https://{args.domain}/"), ("explicit-port", f"https://{args.domain}:8443/")]:
        result = probe(opener, url, args.timeout)
        result.update(kind=kind, passed=acceptable(kind, result, args.domain))
        results.append(result)
    print(json.dumps(results, ensure_ascii=False, indent=2))
    return 0 if all(row["passed"] for row in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
