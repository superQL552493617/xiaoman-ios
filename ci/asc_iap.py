#!/usr/bin/env python3
"""App Store Connect 会员商品：检查 / 创建（年度卡、月度卡订阅 + 永久会员买断）。

用法：python3 ci/asc_iap.py check|setup
环境变量：KEY_ID ISSUER_ID KEY_PATH（GitHub Actions 里从加密的密钥解出来）
只打印商品和价格信息，不打印任何密钥。
"""
import hashlib, json, os, sys, time
import jwt, requests

BASE = "https://api.appstoreconnect.apple.com"
BUNDLE = "site.xiaomanhabit.app"
KEY_ID, ISSUER, KEY_PATH = os.environ["KEY_ID"], os.environ["ISSUER_ID"], os.environ["KEY_PATH"]
KEY = open(KEY_PATH).read()
MODE = (sys.argv[1] if len(sys.argv) > 1 else "check").strip()
SHOT = os.path.join(os.path.dirname(__file__), "iap_review.png")

# 价格：美元优先用 .90 结尾（用户定的 2.9 / 1.9 / 9.9），没有这一档再用 .99；人民币按用户定的
PLANS = {
    "year": dict(pid=BUNDLE + ".vip.year", name="年度卡", period="ONE_YEAR", usd=["2.90", "2.99"], cny=["18.00", "18"],
                 zh=("年度卡", "按年订阅，解锁全部会员功能"), en=("Yearly", "Unlock all premium features, billed yearly")),
    "month": dict(pid=BUNDLE + ".vip.month", name="月度卡", period="ONE_MONTH", usd=["1.90", "1.99"], cny=["3.50", "3.5", "3.00", "3"],
                  zh=("月度卡", "按月订阅，解锁全部会员功能"), en=("Monthly", "Unlock all premium features, billed monthly")),
    "life": dict(pid=BUNDLE + ".vip.life", name="永久会员", usd=["9.90", "9.99"], cny=["35.00", "35"],
                 zh=("永久会员", "一次购买，永久解锁全部会员功能"), en=("Lifetime", "One-time purchase, all premium features forever")),
}
REVIEW_NOTE = "会员解锁：不限习惯数量、照片图标、VIP 图标、全部主题背景。入口：我的 → 开通会员。"

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


def territories():
    d, _ = all_pages("/v1/territories", {"limit": 200})
    return [x["id"] for x in d]


def pick(points, wants):
    by = {}
    for p in points:
        by.setdefault(p["attributes"]["customerPrice"], p)
    for w in wants:
        for k in (w, w.rstrip("0").rstrip(".") if "." in w else w):
            if k in by:
                return by[k]
    return None


def show_points(label, points, lo, hi):
    vals = sorted({float(p["attributes"]["customerPrice"]) for p in points})
    print(f"   {label} 可选价位（{lo}~{hi}）：", ", ".join(f"{v:g}" for v in vals if lo <= v <= hi))


def upload_shot(kind, owner_type, owner_id):
    if not os.path.exists(SHOT):
        print("   （没有审核截图文件，跳过）"); return
    data = open(SHOT, "rb").read()
    rtype = {"subscriptions": "subscriptionAppStoreReviewScreenshots", "inAppPurchases": "inAppPurchaseAppStoreReviewScreenshots"}[owner_type]
    relname = {"subscriptions": "subscription", "inAppPurchases": "inAppPurchaseV2"}[owner_type]
    j = api("POST", f"/v1/{rtype}", {"data": {"type": rtype, "attributes": {"fileName": "vip.png", "fileSize": len(data)},
                                               "relationships": {relname: rel(owner_type, owner_id)}}})
    if not j:
        return
    sid = j["data"]["id"]
    for op in j["data"]["attributes"].get("uploadOperations") or []:
        hdr = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        r = requests.request(op["method"], op["url"], headers=hdr, data=chunk, timeout=120)
        if r.status_code >= 300:
            print("!! 截图上传失败", r.status_code, r.text[:300]); return
    api("PATCH", f"/v1/{rtype}/{sid}", {"data": {"type": rtype, "id": sid,
                                                   "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(f"   审核截图已上传（{kind}）")


# ---------------------------------------------------------------- 检查

def check(app):
    print("== 订阅群组")
    groups, inc = all_pages(f"/v1/apps/{app}/subscriptionGroups", {"include": "subscriptions", "limit": 50})
    subs = {x["id"]: x for x in inc if x["type"] == "subscriptions"}
    found = {}
    for g in groups:
        print(f" - {g['attributes']['referenceName']} ({g['id']})")
        for r in g["relationships"]["subscriptions"]["data"]:
            s = subs.get(r["id"])
            if not s:
                continue
            a = s["attributes"]
            found[a["productId"]] = ("sub", s["id"], g["id"])
            print(f"   · {a['productId']} {a.get('name')} {a.get('subscriptionPeriod')} 状态={a.get('state')}")
            prices, pinc = all_pages(f"/v1/subscriptions/{s['id']}/prices", {"include": "subscriptionPricePoint,territory", "limit": 200})
            pp = {x["id"]: x for x in pinc if x["type"] == "subscriptionPricePoints"}
            for p in prices:
                t = p["relationships"]["territory"]["data"]["id"]
                if t in ("CHN", "USA"):
                    ppid = p["relationships"]["subscriptionPricePoint"]["data"]["id"]
                    print(f"     价格 {t}: {pp.get(ppid, {}).get('attributes', {}).get('customerPrice')}")
            print(f"     已设价格的地区数：{len({p['relationships']['territory']['data']['id'] for p in prices})}")
            offers, _ = all_pages(f"/v1/subscriptions/{s['id']}/introductoryOffers", {"limit": 200})
            if offers:
                o = offers[0]["attributes"]
                print(f"     推介促销：{o.get('offerMode')} {o.get('duration')} × {len(offers)} 个地区")
    print("== App 内购买项目")
    iaps, _ = all_pages(f"/v1/apps/{app}/inAppPurchasesV2", {"limit": 200})
    for i in iaps:
        a = i["attributes"]
        found[a["productId"]] = ("iap", i["id"], None)
        print(f" - {a['productId']} {a.get('name')} {a.get('inAppPurchaseType')} 状态={a.get('state')}")
    for k, p in PLANS.items():
        print(f"{'✓' if p['pid'] in found else '✗'} {p['pid']}")
    return found


# ---------------------------------------------------------------- 创建

def ensure_group(app):
    groups, _ = all_pages(f"/v1/apps/{app}/subscriptionGroups", {"limit": 50})
    for g in groups:
        if g["attributes"]["referenceName"] == "小满会员":
            return g["id"]
    j = api("POST", "/v1/subscriptionGroups", {"data": {"type": "subscriptionGroups", "attributes": {"referenceName": "小满会员"},
                                                          "relationships": {"app": rel("apps", app)}}})
    gid = j["data"]["id"]
    for loc, name in (("zh-Hans", "小满会员"), ("en-US", "Xiaoman Premium")):
        api("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations",
                                                                     "attributes": {"name": name, "locale": loc},
                                                                     "relationships": {"subscriptionGroup": rel("subscriptionGroups", gid)}}})
    print("已创建订阅群组 小满会员")
    return gid


def set_sub_prices(sid, plan, terrs):
    usa, _ = all_pages(f"/v1/subscriptions/{sid}/pricePoints", {"filter[territory]": "USA", "limit": 200})
    chn, _ = all_pages(f"/v1/subscriptions/{sid}/pricePoints", {"filter[territory]": "CHN", "limit": 200})
    show_points("美国", usa, 0.9, 12)
    show_points("中国大陆", chn, 1, 40)
    pu, pc = pick(usa, plan["usd"]), pick(chn, plan["cny"])
    if not pu or not pc:
        print("!! 找不到目标价位", plan["usd"], plan["cny"]); return False
    print(f"   选用：美国 ${pu['attributes']['customerPrice']}，中国大陆 ¥{pc['attributes']['customerPrice']}")
    eq, einc = all_pages(f"/v1/subscriptionPricePoints/{pu['id']}/equalizations", {"include": "territory", "limit": 200})
    by_t = {"USA": pu["id"], "CHN": pc["id"]}
    for e in eq:
        t = e["relationships"]["territory"]["data"]["id"]
        if t not in by_t:
            by_t[t] = e["id"]
    existing, _ = all_pages(f"/v1/subscriptions/{sid}/prices", {"include": "territory", "limit": 200})
    have = {p["relationships"]["territory"]["data"]["id"] for p in existing}
    n = 0
    for t, ppid in by_t.items():
        if t in have or t not in terrs:
            continue
        j = api("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices", "attributes": {"preserveCurrentPrice": False},
                                                             "relationships": {"subscription": rel("subscriptions", sid),
                                                                               "subscriptionPricePoint": rel("subscriptionPricePoints", ppid),
                                                                               "territory": rel("territories", t)}}})
        n += 1 if j else 0
    print(f"   设置了 {n} 个地区的价格（之前已有 {len(have)} 个）")
    return True


def ensure_sub(gid, plan, terrs):
    j = api("GET", f"/v1/subscriptionGroups/{gid}/subscriptions", params={"limit": 50})
    sid = next((s["id"] for s in (j or {}).get("data", []) if s["attributes"]["productId"] == plan["pid"]), None)
    if not sid:
        j = api("POST", "/v1/subscriptions", {"data": {"type": "subscriptions",
                                                        "attributes": {"name": plan["name"], "productId": plan["pid"], "subscriptionPeriod": plan["period"],
                                                                       "familySharable": False, "groupLevel": 1, "reviewNote": REVIEW_NOTE},
                                                        "relationships": {"group": rel("subscriptionGroups", gid)}}})
        if not j:
            return None
        sid = j["data"]["id"]
        print(f"已创建订阅 {plan['pid']}")
        for loc, (name, desc) in (("zh-Hans", plan["zh"]), ("en-US", plan["en"])):
            api("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
                                                                    "attributes": {"name": name, "locale": loc, "description": desc},
                                                                    "relationships": {"subscription": rel("subscriptions", sid)}}})
        api("POST", "/v1/subscriptionAvailabilities", {"data": {"type": "subscriptionAvailabilities", "attributes": {"availableInNewTerritories": True},
                                                                 "relationships": {"subscription": rel("subscriptions", sid),
                                                                                   "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terrs]}}}})
        upload_shot(plan["pid"], "subscriptions", sid)
    else:
        print(f"订阅已存在 {plan['pid']}")
    set_sub_prices(sid, plan, terrs)
    return sid


def ensure_trial(sid, terrs):
    have, inc = all_pages(f"/v1/subscriptions/{sid}/introductoryOffers", {"include": "territory", "limit": 200})
    done = {o["relationships"]["territory"]["data"]["id"] for o in have if o.get("relationships", {}).get("territory", {}).get("data")}
    n = 0
    for t in terrs:
        if t in done:
            continue
        j = api("POST", "/v1/subscriptionIntroductoryOffers", {"data": {"type": "subscriptionIntroductoryOffers",
                                                                         "attributes": {"duration": "THREE_DAYS", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
                                                                         "relationships": {"subscription": rel("subscriptions", sid), "territory": rel("territories", t)}}})
        n += 1 if j else 0
    print(f"   3 天免费试用：新加 {n} 个地区（之前已有 {len(done)} 个）")


def ensure_life(app, plan, terrs):
    iaps, _ = all_pages(f"/v1/apps/{app}/inAppPurchasesV2", {"limit": 200})
    iid = next((i["id"] for i in iaps if i["attributes"]["productId"] == plan["pid"]), None)
    if not iid:
        j = api("POST", "/v2/inAppPurchases", {"data": {"type": "inAppPurchases",
                                                         "attributes": {"name": plan["name"], "productId": plan["pid"], "inAppPurchaseType": "NON_CONSUMABLE",
                                                                        "reviewNote": REVIEW_NOTE, "familySharable": False},
                                                         "relationships": {"app": rel("apps", app)}}})
        if not j:
            return None
        iid = j["data"]["id"]
        print(f"已创建买断项目 {plan['pid']}")
        for loc, (name, desc) in (("zh-Hans", plan["zh"]), ("en-US", plan["en"])):
            api("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations",
                                                                     "attributes": {"name": name, "locale": loc, "description": desc},
                                                                     "relationships": {"inAppPurchaseV2": rel("inAppPurchases", iid)}}})
        api("POST", "/v1/inAppPurchaseAvailabilities", {"data": {"type": "inAppPurchaseAvailabilities", "attributes": {"availableInNewTerritories": True},
                                                                  "relationships": {"inAppPurchase": rel("inAppPurchases", iid),
                                                                                    "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terrs]}}}})
        upload_shot(plan["pid"], "inAppPurchases", iid)
    else:
        print(f"买断项目已存在 {plan['pid']}")
    usa, _ = all_pages(f"/v2/inAppPurchases/{iid}/pricePoints", {"filter[territory]": "USA", "limit": 200})
    chn, _ = all_pages(f"/v2/inAppPurchases/{iid}/pricePoints", {"filter[territory]": "CHN", "limit": 200})
    show_points("美国", usa, 5, 12)
    show_points("中国大陆", chn, 20, 50)
    pu, pc = pick(usa, plan["usd"]), pick(chn, plan["cny"])
    if not pu or not pc:
        print("!! 找不到目标价位"); return iid
    print(f"   选用：美国 ${pu['attributes']['customerPrice']}，中国大陆 ¥{pc['attributes']['customerPrice']}")
    j = api("POST", "/v1/inAppPurchasePriceSchedules", {
        "data": {"type": "inAppPurchasePriceSchedules",
                 "relationships": {"inAppPurchase": rel("inAppPurchases", iid), "baseTerritory": rel("territories", "USA"),
                                   "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p1}"}, {"type": "inAppPurchasePrices", "id": "${p2}"}]}}},
        "included": [
            {"type": "inAppPurchasePrices", "id": "${p1}", "attributes": {"startDate": None},
             "relationships": {"inAppPurchaseV2": rel("inAppPurchases", iid), "inAppPurchasePricePoint": rel("inAppPurchasePricePoints", pu["id"])}},
            {"type": "inAppPurchasePrices", "id": "${p2}", "attributes": {"startDate": None},
             "relationships": {"inAppPurchaseV2": rel("inAppPurchases", iid), "inAppPurchasePricePoint": rel("inAppPurchasePricePoints", pc["id"])}}]})
    print("   价格表已设置" if j else "   价格表设置失败")
    return iid


def main():
    app = app_id()
    if not app:
        print("!! 找不到 App", BUNDLE); return 1
    print("App ID:", app)
    if MODE == "setup":
        terrs = territories()
        print("地区数：", len(terrs))
        gid = ensure_group(app)
        for k in ("year", "month"):
            print(f"== {PLANS[k]['name']}")
            sid = ensure_sub(gid, PLANS[k], terrs)
            if sid and k == "year":
                ensure_trial(sid, terrs)
        print("== 永久会员")
        ensure_life(app, PLANS["life"], terrs)
        print()
    check(app)
    return 0


if __name__ == "__main__":
    sys.exit(main())
