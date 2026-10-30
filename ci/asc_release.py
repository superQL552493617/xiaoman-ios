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
        "attributes": {"copyright": "2026 superQL", "releaseType": "AFTER_APPROVAL"}}}) and print("ok copyright")
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

def version_and_loc(aid):
    ver = [v for v in all_pages(f"/v1/apps/{aid}/appStoreVersions")[0] if v["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")][0]
    vl = first(f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")
    return ver, vl

def upload_shots():
    aid = app_id(); ver, vl = version_and_loc(aid)
    files = sorted(glob.glob(os.path.join(os.path.dirname(__file__), "appstore", "*.png")))
    print("files", [os.path.basename(f) for f in files])
    sets, _ = all_pages(f"/v1/appStoreVersionLocalizations/{vl['id']}/appScreenshotSets")
    st = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
    if not st:
        st = api("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
            "relationships": {"appStoreVersionLocalization": rel("appStoreVersionLocalizations", vl["id"])}}})["data"]
    old, _ = all_pages(f"/v1/appScreenshotSets/{st['id']}/appScreenshots")
    for o in old: api("DELETE", f"/v1/appScreenshots/{o['id']}")
    for f in files:
        data = open(f, "rb").read()
        r = api("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": os.path.basename(f), "fileSize": len(data)},
            "relationships": {"appScreenshotSet": rel("appScreenshotSets", st["id"])}}})
        if not r: continue
        sid = r["data"]["id"]
        for op in r["data"]["attributes"]["uploadOperations"]:
            hdr = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            chunk = data[op["offset"]: op["offset"] + op["length"]]
            rr = requests.request(op["method"], op["url"], headers=hdr, data=chunk, timeout=120)
            if rr.status_code >= 300: print("upload part failed", rr.status_code)
        api("PATCH", f"/v1/appScreenshots/{sid}", {"data": {"type": "appScreenshots", "id": sid,
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}) and print("ok shot", os.path.basename(f))
    time.sleep(20)
    shots, _ = all_pages(f"/v1/appScreenshotSets/{st['id']}/appScreenshots")
    for x in shots: print(" ", x["attributes"].get("fileName"), (x["attributes"].get("assetDeliveryState") or {}).get("state"))

def review_detail():
    aid = app_id(); ver, _ = version_and_loc(aid)
    c = json.load(open(os.environ["CONTACT_PATH"]))
    attrs = {"contactFirstName": c["first"], "contactLastName": c["last"], "contactPhone": c["phone"], "contactEmail": c["email"],
             "demoAccountRequired": False,
             "notes": "小满记是一款本地的习惯打卡和日记 App，不需要注册登录，所有数据只保存在用户手机上，没有服务器。\n"
                      "会员（年度卡含 3 天免费试用、月度卡、永久会员）入口：我的 → 右上方「开通会员」，可在会员页底部查看用户协议和隐私政策，并可恢复购买。\n"
                      "会员功能：不限习惯数量（免费版最多 4 个）、用照片做习惯图标、App 密码锁和面容 ID 解锁。\n"
                      "首次打开会先请用户同意用户协议和隐私政策，然后是新手引导，可以直接点「跳过」。"}
    j = api("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreReviewDetail")
    if j and j.get("data"):
        r = api("PATCH", f"/v1/appStoreReviewDetails/{j['data']['id']}", {"data": {"type": "appStoreReviewDetails", "id": j["data"]["id"], "attributes": attrs}})
    else:
        r = api("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
            "relationships": {"appStoreVersion": rel("appStoreVersions", ver["id"])}}})
    print("review detail", "ok" if r else "failed")

def submit():
    aid = app_id(); ver, _ = version_and_loc(aid)
    bl, _ = all_pages("/v1/builds", {"filter[app]": aid, "sort": "-uploadedDate", "limit": 5, "filter[processingState]": "VALID"})
    if bl:
        api("PATCH", f"/v1/appStoreVersions/{ver['id']}/relationships/build", {"data": {"type": "builds", "id": bl[0]["id"]}}) and print("ok build", bl[0]["attributes"]["version"])
    # 第一次的会员商品要和这个版本一起送审
    grps, _ = all_pages(f"/v1/apps/{aid}/subscriptionGroups")
    for g in grps:
        subs, _ = all_pages(f"/v1/subscriptionGroups/{g['id']}/subscriptions")
        for sb in subs:
            if sb["attributes"].get("state") == "READY_TO_SUBMIT":
                r = api("POST", "/v1/subscriptionSubmissions", {"data": {"type": "subscriptionSubmissions", "relationships": {"subscription": rel("subscriptions", sb["id"])}}})
                print("sub submit", sb["attributes"]["productId"], "ok" if r else "failed")
    iaps, _ = all_pages(f"/v1/apps/{aid}/inAppPurchasesV2")
    for p in iaps:
        if p["attributes"].get("state") == "READY_TO_SUBMIT":
            r = api("POST", "/v1/inAppPurchaseSubmissions", {"data": {"type": "inAppPurchaseSubmissions", "relationships": {"inAppPurchaseV2": rel("inAppPurchases", p["id"])}}})
            print("iap submit", p["attributes"]["productId"], "ok" if r else "failed")
    subs, _ = all_pages(f"/v1/apps/{aid}/reviewSubmissions")
    rs = next((x for x in subs if x["attributes"].get("state") == "READY_FOR_REVIEW"), None)
    if not rs:
        r = api("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"}, "relationships": {"app": rel("apps", aid)}}})
        rs = r and r["data"]
    if not rs: print("no review submission"); return
    items, _ = all_pages(f"/v1/reviewSubmissions/{rs['id']}/items")
    if not items:
        api("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": rel("reviewSubmissions", rs["id"]), "appStoreVersion": rel("appStoreVersions", ver["id"])}}}) and print("item added")
    r = api("PATCH", f"/v1/reviewSubmissions/{rs['id']}", {"data": {"type": "reviewSubmissions", "id": rs["id"], "attributes": {"submitted": True}}})
    print("SUBMITTED" if r else "submit failed")

if MODE == "shots":
    upload_shots()
if MODE == "review":
    review_detail()
if MODE == "submit":
    submit(); status()

if MODE == "canceldraft":
    aid = app_id()
    subs, _ = all_pages(f"/v1/apps/{aid}/reviewSubmissions")
    for x in subs:
        if x["attributes"].get("state") == "READY_FOR_REVIEW":
            items, _ = all_pages(f"/v1/reviewSubmissions/{x['id']}/items")
            if not items:
                r = api("PATCH", f"/v1/reviewSubmissions/{x['id']}", {"data": {"type": "reviewSubmissions", "id": x["id"], "attributes": {"canceled": True}}})
                print("canceled empty draft", x["id"], r is not None)
    time.sleep(5)
    status()

if MODE.startswith("attach"):
    aid = app_id(); ver, _ = version_and_loc(aid)
    bl, _ = all_pages("/v1/builds", {"filter[app]": aid, "sort": "-uploadedDate", "limit": 3})
    for b in bl: print("build", b["attributes"]["version"], b["attributes"].get("processingState"))
    ok = [b for b in bl if b["attributes"].get("processingState") == "VALID"]
    if ok:
        r = api("PATCH", f"/v1/appStoreVersions/{ver['id']}/relationships/build", {"data": {"type": "builds", "id": ok[0]["id"]}})
        print("ATTACHED", ok[0]["attributes"]["version"], r is not None)

if MODE.startswith("draft"):
    aid = app_id()
    subs, _ = all_pages(f"/v1/apps/{aid}/reviewSubmissions")
    for x in subs:
        print("submission", x["id"], x["attributes"].get("state"), x["attributes"].get("submittedDate"))
        items, inc = all_pages(f"/v1/reviewSubmissions/{x['id']}/items", {"include": "appStoreVersion"})
        for it in items:
            rels = {k: (v.get("data") or {}).get("id") for k, v in it.get("relationships", {}).items() if isinstance(v, dict) and v.get("data")}
            print("  item", it["attributes"].get("state"), rels)
    vers, _ = all_pages(f"/v1/apps/{aid}/appStoreVersions")
    for v in vers: print("version", v["attributes"]["versionString"], v["attributes"].get("appStoreState"))
    grps, _ = all_pages(f"/v1/apps/{aid}/subscriptionGroups")
    for g in grps:
        ss, _ = all_pages(f"/v1/subscriptionGroups/{g['id']}/subscriptions")
        for sb in ss: print("sub", sb["attributes"].get("productId"), sb["attributes"].get("state"))
    iaps, _ = all_pages(f"/v1/apps/{aid}/inAppPurchasesV2")
    for p in iaps: print("iap", p["attributes"].get("productId"), p["attributes"].get("state"))

if MODE.startswith("links"):
    for u in ["https://superql552493617.github.io/", PAGES, PAGES + "privacy.html", PAGES + "terms.html", PAGES + "en/", PAGES + "en/privacy.html", PAGES + "en/terms.html", PAGES + "zh-Hant/", PAGES + "zh-Hant/privacy.html", PAGES + "zh-Hant/terms.html", "https://wj.qq.com/s2/28298368/emfy/", "https://beian.miit.gov.cn/"]:
        try:
            r = requests.get(u, timeout=20); print("LINK", r.status_code, u, len(r.text))
        except Exception as e:
            print("LINK ERR", u, e)

# ================= 多语言上架（1.0 过审后再用）=================
# newversion 1.1   新建版本（1.0 上架后）
# locales          英文 / 繁体：App 名称、副标题、隐私政策网址、描述、关键词、更新说明、会员商品名称
# world            开放全部国家和地区（价格：中国大陆按人民币，其余按美元自动换算）
# lshots           上传 ci/appstore/<语言>/*.png 截图
LOC_DIR = os.path.join(os.path.dirname(__file__), "appstore", "locales")

def editable_version(aid):
    vs = all_pages(f"/v1/apps/{aid}/appStoreVersions")[0]
    ok = [v for v in vs if v["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")]
    return ok[0] if ok else None

def new_version(vs):
    aid = app_id()
    if editable_version(aid): print("already have an editable version"); return
    r = api("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions", "attributes": {"platform": "IOS", "versionString": vs, "releaseType": "AFTER_APPROVAL", "copyright": "2026 superQL"},
        "relationships": {"app": rel("apps", aid)}}})
    print("new version", vs, "ok" if r else "failed")

def locales():
    aid = app_id()
    infos, _ = all_pages(f"/v1/apps/{aid}/appInfos")
    inf = next((i for i in infos if (i["attributes"].get("appStoreState") or i["attributes"].get("state")) not in ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION")), infos[0])
    ver = editable_version(aid)
    for f in sorted(glob.glob(os.path.join(LOC_DIR, "*.json"))):
        loc = os.path.basename(f)[:-5]; d = json.load(open(f))
        # App 名称、副标题、隐私政策
        il, _ = all_pages(f"/v1/appInfos/{inf['id']}/appInfoLocalizations")
        cur = next((x for x in il if x["attributes"]["locale"] == loc), None)
        attrs = {"name": d["name"], "subtitle": d["subtitle"], "privacyPolicyUrl": d["privacyPolicyUrl"]}
        if cur: r = api("PATCH", f"/v1/appInfoLocalizations/{cur['id']}", {"data": {"type": "appInfoLocalizations", "id": cur["id"], "attributes": attrs}})
        else: r = api("POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": dict(attrs, locale=loc), "relationships": {"appInfo": rel("appInfos", inf["id"])}}})
        print(loc, "appInfo", "ok" if r else "failed")
        # 版本描述
        if ver:
            vl, _ = all_pages(f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")
            cur = next((x for x in vl if x["attributes"]["locale"] == loc), None)
            attrs = {k: d[k] for k in ("description", "keywords", "promotionalText", "supportUrl", "marketingUrl", "whatsNew")}
            if cur: r = api("PATCH", f"/v1/appStoreVersionLocalizations/{cur['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": cur["id"], "attributes": attrs}})
            else:
                a2 = dict(attrs, locale=loc); a2.pop("whatsNew", None)
                r = api("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": a2, "relationships": {"appStoreVersion": rel("appStoreVersions", ver["id"])}}})
                if r: api("PATCH", f"/v1/appStoreVersionLocalizations/{r['data']['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": r["data"]["id"], "attributes": {"whatsNew": d["whatsNew"]}}})
            print(loc, "version", "ok" if r else "failed")
        else:
            print("no editable version: run 'newversion 1.1' first")
        # 会员商品名称
        grps, _ = all_pages(f"/v1/apps/{aid}/subscriptionGroups")
        for g in grps:
            gl, _ = all_pages(f"/v1/subscriptionGroups/{g['id']}/subscriptionGroupLocalizations")
            if not any(x["attributes"]["locale"] == loc for x in gl):
                r = api("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations", "attributes": {"locale": loc, "name": d["group"]},
                    "relationships": {"subscriptionGroup": rel("subscriptionGroups", g["id"])}}}); print(loc, "group", "ok" if r else "failed")
            subs, _ = all_pages(f"/v1/subscriptionGroups/{g['id']}/subscriptions")
            for sb in subs:
                pid = sb["attributes"]["productId"]; nm = d["iap"].get(pid)
                if not nm: continue
                sl, _ = all_pages(f"/v1/subscriptions/{sb['id']}/subscriptionLocalizations")
                cur = next((x for x in sl if x["attributes"]["locale"] == loc), None)
                if cur: r = api("PATCH", f"/v1/subscriptionLocalizations/{cur['id']}", {"data": {"type": "subscriptionLocalizations", "id": cur["id"], "attributes": {"name": nm[0], "description": nm[1]}}})
                else: r = api("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations", "attributes": {"locale": loc, "name": nm[0], "description": nm[1]},
                    "relationships": {"subscription": rel("subscriptions", sb["id"])}}})
                print(loc, pid, "ok" if r else "failed")
        iaps, _ = all_pages(f"/v1/apps/{aid}/inAppPurchasesV2")
        for p in iaps:
            pid = p["attributes"]["productId"]; nm = d["iap"].get(pid)
            if not nm: continue
            pl, _ = all_pages(f"/v2/inAppPurchases/{p['id']}/inAppPurchaseLocalizations")
            cur = next((x for x in pl if x["attributes"]["locale"] == loc), None)
            if cur: r = api("PATCH", f"/v1/inAppPurchaseLocalizations/{cur['id']}", {"data": {"type": "inAppPurchaseLocalizations", "id": cur["id"], "attributes": {"name": nm[0], "description": nm[1]}}})
            else: r = api("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations", "attributes": {"locale": loc, "name": nm[0], "description": nm[1]},
                "relationships": {"inAppPurchaseV2": rel("inAppPurchases", p["id"])}}})
            print(loc, pid, "ok" if r else "failed")

def world(aid):
    terrs, _ = all_pages("/v1/territories", {"limit": 200})
    ids = [t["id"] for t in terrs]
    data = [{"type": "territoryAvailabilities", "id": "${t%s}" % t} for t in ids]
    inc = [{"type": "territoryAvailabilities", "id": "${t%s}" % t, "attributes": {"available": True},
            "relationships": {"territory": rel("territories", t)}} for t in ids]
    av = api("POST", "/v2/appAvailabilities", {"data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True},
        "relationships": {"app": rel("apps", aid), "territoryAvailabilities": {"data": data}}}, "included": inc})
    print("world availability", "ok" if av else "failed", len(ids), "territories")

def local_shots():
    aid = app_id(); ver = editable_version(aid)
    if not ver: print("no editable version"); return
    vl, _ = all_pages(f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")
    for l in vl:
        loc = l["attributes"]["locale"]
        files = sorted(glob.glob(os.path.join(os.path.dirname(__file__), "appstore", loc, "*.png")))
        if loc == "zh-Hans": files = sorted(glob.glob(os.path.join(os.path.dirname(__file__), "appstore", "*.png")))
        if not files: print(loc, "no screenshots"); continue
        sets, _ = all_pages(f"/v1/appStoreVersionLocalizations/{l['id']}/appScreenshotSets")
        st = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
        if not st:
            st = api("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
                "relationships": {"appStoreVersionLocalization": rel("appStoreVersionLocalizations", l["id"])}}})["data"]
        old, _ = all_pages(f"/v1/appScreenshotSets/{st['id']}/appScreenshots")
        for o in old: api("DELETE", f"/v1/appScreenshots/{o['id']}")
        for f in files:
            data = open(f, "rb").read()
            r = api("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": os.path.basename(f), "fileSize": len(data)},
                "relationships": {"appScreenshotSet": rel("appScreenshotSets", st["id"])}}})
            if not r: continue
            sid = r["data"]["id"]
            for op in r["data"]["attributes"]["uploadOperations"]:
                hdr = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
                rr = requests.request(op["method"], op["url"], headers=hdr, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120)
                if rr.status_code >= 300: print("upload part failed", rr.status_code)
            api("PATCH", f"/v1/appScreenshots/{sid}", {"data": {"type": "appScreenshots", "id": sid,
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}) and print(loc, "ok shot", os.path.basename(f))

if MODE.startswith("newversion"):
    new_version(MODE.split()[1] if len(MODE.split()) > 1 else "1.1")
if MODE == "locales":
    locales(); status()
if MODE == "world":
    world(app_id())
if MODE == "lshots":
    local_shots()
if MODE in ("manual", "auto"):
    aid = app_id(); ver = editable_version(aid)
    rt = "MANUAL" if MODE == "manual" else "AFTER_APPROVAL"
    r = api("PATCH", f"/v1/appStoreVersions/{ver['id']}", {"data": {"type": "appStoreVersions", "id": ver["id"], "attributes": {"releaseType": rt}}})
    print("releaseType", rt, "ok" if r else "failed")
if MODE == "withdraw":
    aid = app_id()
    subs, _ = all_pages(f"/v1/apps/{aid}/reviewSubmissions")
    for x in subs:
        if x["attributes"].get("state") in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
            r = api("PATCH", f"/v1/reviewSubmissions/{x['id']}", {"data": {"type": "reviewSubmissions", "id": x["id"], "attributes": {"canceled": True}}})
            print("withdraw", x["id"], "ok" if r else "failed")
    time.sleep(20)
if MODE.startswith("copyright"):
    aid = app_id(); ver = editable_version(aid)
    cp = MODE.split(" ", 1)[1] if " " in MODE else "2026 superQL"
    if ver:
        r = api("PATCH", f"/v1/appStoreVersions/{ver['id']}", {"data": {"type": "appStoreVersions", "id": ver["id"], "attributes": {"copyright": cp}}})
        print("copyright", cp, "ok" if r else "failed")
    else: print("no editable version")
if MODE in ("withdraw",) or MODE.startswith("copyright"):
    for v in all_pages(f"/v1/apps/{aid}/appStoreVersions")[0]: print("version", v["attributes"]["versionString"], v["attributes"].get("appStoreState"), v["attributes"].get("copyright"))
