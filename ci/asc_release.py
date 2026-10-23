#!/usr/bin/env python3
"""App Store Connect 上架：查看状态 / 填写资料 / 上传截图 / 提交审核（只打印状态，不打印密钥）。
用法：python3 ci/asc_release.py status|meta|shots|submit
"""
import hashlib, json, os, sys, time, glob
import jwt, requests

BASE = "https://api.appstoreconnect.apple.com"
BUNDLE = "site.xiaomanhabit.app"
KEY_ID, ISSUER, KEY_PATH = os.environ["KEY_ID"], os.environ["ISSUER_ID"], os.environ["KEY_PATH"]
KEY = open(KEY_PATH).read()

_tok = [None, 0]


def token():
    if not _tok[0] or time.time() > _tok[1] - 60:
        now = int(time.time())
        _tok[0] = jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}, KEY,
                             algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})
        _tok[1] = now + 1100
    return _tok[0]


def api(method, path, body=None, params=None, ok=(200, 201, 204)):
    url = path if path.startswith("http") else BASE + path
    for attempt in range(4):
        r = requests.request(method, url, headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"},
                             json=body, params=params, timeout=60)
        if r.status_code == 429:
            time.sleep(10 * (attempt + 1)); continue
        break
    if r.status_code not in ok:
        print(f"!! {method} {path} -> {r.status_code}: {r.text[:1500]}")
        return None
    return r.json() if r.text else {}


def all_pages(path, params=None):
    out, inc = [], []
    j = api("GET", path, params=params)
    while j:
        out += j.get("data", [])
        inc += j.get("included", [])
        nxt = j.get("links", {}).get("next")
        j = api("GET", nxt) if nxt else None
    return out, inc


def rel(t, i):
    return {"data": {"type": t, "id": i}}


def app_id():
    j = api("GET", "/v1/apps", params={"filter[bundleId]": BUNDLE})
    return j["data"][0]["id"] if j and j["data"] else None



MODE = (sys.argv[1] if len(sys.argv) > 1 else "status").strip()

def show(title, obj):
    print("== " + title)
    print(json.dumps(obj, ensure_ascii=False, indent=1)[:4000])

def status():
    aid = app_id(); print("app", aid)
    infos, _ = all_pages(f"/v1/apps/{aid}/appInfos")
    for inf in infos:
        a = inf["attributes"]
        print("appInfo", inf["id"], a.get("appStoreState") or a.get("state"), a.get("appStoreAgeRating"))
        locs, _ = all_pages(f"/v1/appInfos/{inf['id']}/appInfoLocalizations")
        for l in locs: show("appInfoLoc " + l["attributes"]["locale"], l["attributes"])
        for r in ["primaryCategory", "secondaryCategory"]:
            j = api("GET", f"/v1/appInfos/{inf['id']}/{r}")
            print(r, j and j.get("data") and j["data"]["id"])
        j = api("GET", f"/v1/appInfos/{inf['id']}/ageRatingDeclaration")
        if j and j.get("data"): show("ageRating", j["data"]["attributes"])
    vers, _ = all_pages(f"/v1/apps/{aid}/appStoreVersions")
    for v in vers:
        a = v["attributes"]; print("version", v["id"], a["versionString"], a.get("appStoreState"), a.get("platform"), "release:", a.get("releaseType"))
        locs, _ = all_pages(f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")
        for l in locs:
            show("verLoc " + l["attributes"]["locale"], l["attributes"])
            sets, _ = all_pages(f"/v1/appStoreVersionLocalizations/{l['id']}/appScreenshotSets")
            for st in sets:
                shots, _ = all_pages(f"/v1/appScreenshotSets/{st['id']}/appScreenshots")
                print("  shots", st["attributes"]["screenshotDisplayType"], len(shots))
        j = api("GET", f"/v1/appStoreVersions/{v['id']}/build")
        print("  build", j and j.get("data") and (j["data"]["id"], j["data"]["attributes"].get("version")))
        j = api("GET", f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail")
        if j and j.get("data"): show("reviewDetail", {k: v2 for k, v2 in j["data"]["attributes"].items() if k not in ("contactPhone", "contactEmail")})
        else: print("  reviewDetail none")
    bl, _ = all_pages("/v1/builds", {"filter[app]": aid, "sort": "-uploadedDate", "limit": 5})
    for b in bl[:5]:
        a = b["attributes"]; print("build", b["id"], a.get("version"), a.get("processingState"), a.get("usesNonExemptEncryption"), a.get("expired"))
    j = api("GET", f"/v1/apps/{aid}/appAvailabilityV2")
    print("availability", j and j.get("data") and j["data"]["attributes"])
    if j and j.get("data"):
        ta, _ = all_pages(f"/v2/appAvailabilities/{j['data']['id']}/territoryAvailabilities", {"limit": 200, "include": "territory"})
        on = [x["relationships"]["territory"]["data"]["id"] for x in ta if x["attributes"].get("available")]
        print("territories available:", len(on), on[:10])
    j = api("GET", f"/v1/apps/{aid}/appPriceSchedule", params={"include": "baseTerritory,manualPrices"})
    print("priceSchedule", j and j.get("data") and j["data"]["id"], j and [i.get("type") + ":" + i.get("id") for i in j.get("included", [])][:5])
    grps, _ = all_pages(f"/v1/apps/{aid}/subscriptionGroups")
    for g in grps:
        subs, _ = all_pages(f"/v1/subscriptionGroups/{g['id']}/subscriptions")
        gl, _ = all_pages(f"/v1/subscriptionGroups/{g['id']}/subscriptionGroupLocalizations")
        print("subGroup", g["attributes"].get("referenceName"), "locs", [x["attributes"].get("locale") + ":" + str(x["attributes"].get("state")) for x in gl])
        for s in subs: print("  sub", s["attributes"].get("productId"), s["attributes"].get("state"))
    iaps, _ = all_pages(f"/v1/apps/{aid}/inAppPurchasesV2")
    for p in iaps: print("iap", p["attributes"].get("productId"), p["attributes"].get("state"))
    subs, _ = all_pages(f"/v1/apps/{aid}/reviewSubmissions")
    for s in subs: print("reviewSubmission", s["id"], s["attributes"].get("state"), s["attributes"].get("platform"))

if MODE == "status":
    status()
