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

PAGES = "https://superql552493617.github.io/xiaoman-ios/"
DESC = """小满记，一个简单温柔的习惯打卡和日记 App。每天点亮几个小习惯，写几句日志和笔记，日子就慢慢满了。

【轻轻一点就打卡】
· 点一下圆圈完成打卡，有动画、音效和震动反馈
· 再点已打卡的圆圈，写下当时的感受
· 左右滑动切换日期，忘了也能补打卡
· 每个习惯可以选图标、颜色、形状和打卡日

【闹钟提醒，不会忘】
· 每个习惯可以设置多个提醒时间
· 到点响铃，没打卡会再提醒；已经打卡的不再打扰

【笔记和心情】
· 随手写笔记，记录每天的心情
· 回忆页按日期翻看过去的记录

【统计与回顾】
· 按周、月、年查看完成率和打卡次数
· 每周生成一份打卡总结

【桌面小组件】
· 在桌面直接打卡，打完的自动消失
· 笔记小组件一点就写，桌面上不显示笔记内容

【装扮成你喜欢的样子】
· 多种主题、字体、图标形状和配色
· 可以用自己的照片做习惯图标（会员）

【安全和隐私】
· 不用注册登录，数据只保存在你的手机上
· 支持密码锁和面容 ID（会员）
· 随时导出备份

会员说明：
· 年度卡（首次可免费试用 3 天）、月度卡为自动续期订阅，到期前 24 小时内自动续费，可随时在「设置 → Apple ID → 订阅」中取消；永久会员为一次性购买。
· 用户协议：""" + PAGES + """terms.html
· 隐私政策：""" + PAGES + """privacy.html"""
KEYWORDS = "习惯,打卡,自律,日记,笔记,提醒,闹钟,目标,计划,心情,早起,健身,喝水,读书,小组件"
PROMO = "每天一点点，日子慢慢满。简单好用的习惯打卡和日记本。"

def first(path):
    j = api("GET", path); d = j and j.get("data")
    return (d[0] if isinstance(d, list) and d else d) if d else None

def avail(aid):
    # 只在中国大陆上架：所有地区都要列出来，中国大陆 = 上架，其他 = 不上架
    terrs, _ = all_pages("/v1/territories", {"limit": 200})
    ids = [t["id"] for t in terrs]
    data = [{"type": "territoryAvailabilities", "id": "${t%s}" % t} for t in ids]
    inc = [{"type": "territoryAvailabilities", "id": "${t%s}" % t, "attributes": {"available": t == "CHN"},
            "relationships": {"territory": rel("territories", t)}} for t in ids]
    inc += [{"type": "territories", "id": t} for t in ids]
    av = api("POST", "/v2/appAvailabilities", {"data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": False},
        "relationships": {"app": rel("apps", aid), "territoryAvailabilities": {"data": data}}}, "included": inc})
    print("availability", "ok" if av else "failed", len(ids), "territories")

def meta():
    aid = app_id()
    inf = first(f"/v1/apps/{aid}/appInfos")
    loc = first(f"/v1/appInfos/{inf['id']}/appInfoLocalizations")
    api("PATCH", f"/v1/appInfoLocalizations/{loc['id']}", {"data": {"type": "appInfoLocalizations", "id": loc["id"],
        "attributes": {"privacyPolicyUrl": PAGES + "privacy.html"}}}) and print("ok privacyPolicyUrl")
    api("PATCH", f"/v1/appInfos/{inf['id']}", {"data": {"type": "appInfos", "id": inf["id"], "relationships": {
        "primaryCategory": rel("appCategories", "PRODUCTIVITY"), "secondaryCategory": rel("appCategories", "LIFESTYLE")}}}) and print("ok categories")
    ar = first(f"/v1/appInfos/{inf['id']}/ageRatingDeclaration")
    if ar:
        attrs = {}
        for k, v in ar["attributes"].items():
            if k in ("ageRatingOverride", "ageRatingOverrideV2", "koreaAgeRatingOverride", "gracRatingClassificationNumber", "developerAgeRatingInfoUrl", "kidsAgeBand"):
                continue
            attrs[k] = v
        enums = ["alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons", "medicalOrTreatmentInformation",
                 "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity", "horrorOrFearThemes", "matureOrSuggestiveThemes",
                 "violenceCartoonOrFantasy", "violenceRealisticProlongedGraphicOrSadistic", "violenceRealistic"]
        bools = ["advertising", "gambling", "healthOrWellnessTopics", "lootBox", "messagingAndChat", "parentalControls", "ageAssurance",
                 "socialMedia", "socialMediaAgeRestricted", "unrestrictedWebAccess", "userGeneratedContent"]
        body = {k: "NONE" for k in enums if k in ar["attributes"]}
        body.update({k: False for k in bools if k in ar["attributes"]})
        r = api("PATCH", f"/v1/ageRatingDeclarations/{ar['id']}", {"data": {"type": "ageRatingDeclarations", "id": ar["id"], "attributes": body}})
        if not r:   # 有的字段在这个账号里不能改：逐个试
            for k, v in body.items():
                api("PATCH", f"/v1/ageRatingDeclarations/{ar['id']}", {"data": {"type": "ageRatingDeclarations", "id": ar["id"], "attributes": {k: v}}})
        print("ok ageRating")
    api("PATCH", f"/v1/apps/{aid}", {"data": {"type": "apps", "id": aid, "attributes": {"contentRightsDeclaration": "USES_THIRD_PARTY_CONTENT"}}}) and print("ok contentRights")
    ver = [v for v in all_pages(f"/v1/apps/{aid}/appStoreVersions")[0] if v["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")][0]
    api("PATCH", f"/v1/appStoreVersions/{ver['id']}", {"data": {"type": "appStoreVersions", "id": ver["id"],
        "attributes": {"copyright": "2026 lang qin", "releaseType": "AFTER_APPROVAL"}}}) and print("ok copyright")
    vl = first(f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")
    api("PATCH", f"/v1/appStoreVersionLocalizations/{vl['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": vl["id"],
        "attributes": {"description": DESC, "keywords": KEYWORDS, "promotionalText": PROMO, "supportUrl": PAGES, "marketingUrl": PAGES}}}) and print("ok description")
    # 选最新处理完成的包
    bl, _ = all_pages("/v1/builds", {"filter[app]": aid, "sort": "-uploadedDate", "limit": 5, "filter[processingState]": "VALID"})
    if bl:
        b = bl[0]
        api("PATCH", f"/v1/appStoreVersions/{ver['id']}/relationships/build", {"data": {"type": "builds", "id": b["id"]}}) and print("ok build", b["attributes"]["version"])
    avail(aid)
    # 免费下载
    pts, _ = all_pages(f"/v1/apps/{aid}/appPricePoints", {"filter[territory]": "CHN", "limit": 200})
    free = [p for p in pts if float(p["attributes"].get("customerPrice") or 0) == 0]
    if free:
        ps = api("POST", "/v1/appPriceSchedules", {"data": {"type": "appPriceSchedules", "relationships": {"app": rel("apps", aid),
            "baseTerritory": rel("territories", "CHN"), "manualPrices": {"data": [{"type": "appPrices", "id": "${p0}"}]}}},
            "included": [{"type": "appPrices", "id": "${p0}", "attributes": {"startDate": None},
                          "relationships": {"appPricePoint": rel("appPricePoints", free[0]["id"])}}]})
        print("price free", "ok" if ps else "failed")
    else:
        print("no free price point found")

if MODE == "avail":
    avail(app_id())

if MODE == "meta":
    meta(); status()
