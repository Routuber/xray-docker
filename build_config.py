#!/usr/bin/env python3
import json
import re
import sys
from typing import Any, Dict, List

def slug(s: str) -> str:
    s = (s or "").strip()
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"[^\w\-\s\(\)\[\]🇦-🇿]", "", s, flags=re.UNICODE)
    s = s.replace(" ", "_")
    return s[:40] if s else "node"

def load_sub(payload: str) -> List[Dict[str, Any]]:
    data = json.loads(payload)
    if isinstance(data, dict):
        return [data]
    if isinstance(data, list):
        return [x for x in data if isinstance(x, dict)]
    raise ValueError("Unexpected JSON type")

def extract_proxy_outbounds(cfg: Dict[str, Any]) -> List[Dict[str, Any]]:
    outs = cfg.get("outbounds", [])
    if not isinstance(outs, list):
        return []
    res = []
    for ob in outs:
        if not isinstance(ob, dict):
            continue
        tag = ob.get("tag")
        if tag in ("direct", "block"):
            continue
        if ob.get("protocol"):
            res.append(ob)
    return res

def main():
    if len(sys.argv) != 4:
        print("Usage: build_config.py <base_template.json> <sub_payload.json> <out_config.json>", file=sys.stderr)
        sys.exit(2)

    base_path, sub_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    base = json.load(open(base_path, "r", encoding="utf-8"))
    sub_payload = open(sub_path, "r", encoding="utf-8").read()
    cfgs = load_sub(sub_payload)

    outbounds: List[Dict[str, Any]] = []
    tags: List[str] = []

    idx = 1
    for cfg in cfgs:
        remarks = cfg.get("remarks") or cfg.get("ps") or ""
        outs = extract_proxy_outbounds(cfg)
        for ob in outs:
            new = json.loads(json.dumps(ob))
            new_tag = f"sub{idx:03d}_{slug(remarks)}"
            new["tag"] = new_tag
            outbounds.append(new)
            tags.append(new_tag)
            idx += 1

    if not outbounds:
        raise SystemExit("No proxy outbounds found in subscription JSON")

    base_outs = base.get("outbounds", [])
    if not isinstance(base_outs, list):
        base_outs = []
    base["outbounds"] = outbounds + base_outs

    base["routing"]["balancers"][0]["selector"] = tags
    base["observatory"]["subjectSelector"] = tags

    json.dump(base, open(out_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

if __name__ == "__main__":
    main()