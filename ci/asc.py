#!/usr/bin/env python3
"""用 App Store Connect API 做一次性准备：注册 Bundle ID、创建发布证书。
在 GitHub Actions 里运行，结果写到 out/ 目录。"""
import json, os, sys, time, base64, urllib.request, urllib.error, urllib.parse, traceback
import jwt

KEY_ID = os.environ["ASC_KEY_ID"]; ISSUER = os.environ["ASC_ISSUER_ID"]
KEY = open(os.environ["ASC_KEY_PATH"]).read()
API = "https://api.appstoreconnect.apple.com"
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(OUT, exist_ok=True)
log = []

def token():
    now = int(time.time())
    return jwt.encode({"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      KEY, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})

def call(method, path, body=None):
    path = urllib.parse.quote(path, safe="/?=&[]:.-_")
    req = urllib.request.Request(API + path, method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            t = r.read().decode(); return r.status, (json.loads(t) if t else {})
    except urllib.error.HTTPError as e:
        t = e.read().decode()
        try: return e.code, json.loads(t)
        except Exception: return e.code, {"raw": t}

cfg = json.load(open("ci/setup.json"))
result = {"bundleIds": {}, "certificate": None}

for ident, name in [(cfg["bundleId"], cfg.get("name", "App")), (cfg["bundleId"] + ".widget", cfg.get("name", "App") + " Widget")]:
    s, r = call("GET", f"/v1/bundleIds?filter[identifier]={ident}&limit=5")
    found = [d for d in r.get("data", []) if d["attributes"]["identifier"] == ident]
    if found:
        result["bundleIds"][ident] = {"status": "exists", "id": found[0]["id"], "seedId": found[0]["attributes"].get("seedId")}
        continue
    s, r = call("POST", "/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {"identifier": ident, "name": name.encode('ascii','ignore').decode() or "App", "platform": "IOS"}}})
    if s in (200, 201):
        d = r["data"]; result["bundleIds"][ident] = {"status": "created", "id": d["id"], "seedId": d["attributes"].get("seedId")}
        # 打开 App Groups 能力
        s2, r2 = call("POST", "/v1/bundleIdCapabilities", {"data": {"type": "bundleIdCapabilities",
            "attributes": {"capabilityType": "APP_GROUPS"},
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": d["id"]}}}}})
        result["bundleIds"][ident]["appGroupsCapability"] = s2
    else:
        result["bundleIds"][ident] = {"status": "failed", "http": s, "errors": r.get("errors", r)}

if cfg.get("createCertificate") and not os.path.exists("ci/dist.cer"):
    csr = open("ci/dist.csr").read()
    s, r = call("POST", "/v1/certificates", {"data": {"type": "certificates",
        "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr}}})
    if s in (200, 201):
        content = r["data"]["attributes"]["certificateContent"]
        open(os.path.join(OUT, "dist.cer"), "wb").write(base64.b64decode(content))
        result["certificate"] = {"status": "created", "id": r["data"]["id"], "name": r["data"]["attributes"].get("name"),
                                 "expires": r["data"]["attributes"].get("expirationDate")}
    else:
        result["certificate"] = {"status": "failed", "http": s, "errors": r.get("errors", r)}
        s, r = call("GET", "/v1/certificates?limit=20")
        result["existingCertificates"] = [{"id": d["id"], "type": d["attributes"].get("certificateType"),
            "name": d["attributes"].get("name"), "expires": d["attributes"].get("expirationDate")} for d in r.get("data", [])]

# 生成 App Store 描述文件（需要先在网页上把 App Group 分配给 Bundle ID）
if cfg.get("profiles"):
    result["profiles"] = {}
    s, r = call("GET", "/v1/certificates?filter[certificateType]=DISTRIBUTION&limit=20")
    certs = [d["id"] for d in r.get("data", [])]
    cert_id = cfg.get("certificateId") if cfg.get("certificateId") in certs else (certs[0] if certs else None)
    for ident, info in result["bundleIds"].items():
        pname = "Xiaoman AppStore " + ident
        s, r = call("GET", f"/v1/profiles?filter[name]={pname}&limit=10")
        for d in r.get("data", []):
            call("DELETE", f"/v1/profiles/{d['id']}")
        s, r = call("POST", "/v1/profiles", {"data": {"type": "profiles",
            "attributes": {"name": pname, "profileType": "IOS_APP_STORE"},
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": info["id"]}},
                              "certificates": {"data": [{"type": "certificates", "id": cert_id}]}}}})
        if s in (200, 201):
            fn = ident + ".mobileprovision"
            open(os.path.join(OUT, fn), "wb").write(base64.b64decode(r["data"]["attributes"]["profileContent"]))
            result["profiles"][ident] = {"status": "created", "name": pname, "uuid": r["data"]["attributes"].get("uuid"), "file": fn}
        else:
            result["profiles"][ident] = {"status": "failed", "http": s, "errors": r.get("errors", r)}

json.dump(result, open(os.path.join(OUT, "result.json"), "w"), ensure_ascii=False, indent=2)
print(json.dumps(result, ensure_ascii=False, indent=2))
