#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
push.py
根据 merger_server_files.py 生成的 md5_map.json，把文件推送到服务器共享目录:

  1. 读取 files.txt (形如 {"all_files_dic": {绝对路径: {md5, ue_dir, ...}}})；
  2. 对每个文件, 用其 md5 在 md5_map.json (md5 -> 移动后的文件路径) 中查找；
  3. 找到则把 md5_map.json 中对应的文件拷贝到 server_root_dir + user_name + ue_dir；
  4. 输出双向统计:
       - files.txt 中每个文件: md5 是否找到, 找到后是否复制成功
       - md5_map.json 中每个文件: 是否被 files.txt 关联, 关联后是否复制成功
     完整明细保存为 CSV 报告, 控制台打印统计摘要。

用法(参数均有默认值, 可直接运行):
    python push.py [--server_root_dir \\\\192.168.3.238\\disk1t\\files_root_dir\\]
                   [--files_txt E:\\output\\files.txt]
                   [--md5_json E:\\output\\md5_map.json]
                   [--user_name jbl]
                   [--report_dir 报告输出目录, 默认脚本目录]
"""

import argparse
import csv
import json
import os
import shutil
import sys


def _ensure_utf8_stdout():
    """Windows 控制台默认编码可能是 GBK, 强制 UTF-8 避免打印中文报错。"""
    try:
        if sys.stdout is not None and hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        if sys.stderr is not None and hasattr(sys.stderr, "reconfigure"):
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def load_json(path: str, label: str):
    """读取 JSON 文件, 兼容 UTF-8 与 UTF-8 BOM。失败时给出明确报错。"""
    if not os.path.exists(path):
        print("[ERROR] %s 文件不存在: %s" % (label, path))
        sys.exit(1)
    for enc in ("utf-8-sig", "utf-8", "gbk"):
        try:
            with open(path, "r", encoding=enc) as fp:
                data = json.load(fp)
            print("[OK] 已读取 %s: %s (%s)" % (label, path, enc))
            return data
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
    print("[ERROR] %s 解析失败, 编码/格式不支持: %s" % (label, path))
    sys.exit(1)


def build_dest_path(server_root_dir: str, user_name: str, ue_dir: str) -> str:
    """拼接目标路径: server_root_dir + user_name + ue_dir, 统一分隔符为反斜杠。"""
    root = server_root_dir.rstrip("/\\")
    user = user_name.strip().strip("/\\")
    rel = ue_dir.strip().lstrip("/\\").replace("/", os.sep).replace("\\", os.sep)
    return os.path.join(root, user, rel) if user else os.path.join(root, rel)


def copy_one(src: str, dest: str):
    """拷贝单个文件, 返回 (状态, 说明)。状态: ok / exists / failed。"""
    if not os.path.exists(src):
        return "failed", "源文件不存在: %s" % src
    try:
        if os.path.exists(dest):
            try:
                if os.path.getsize(dest) == os.path.getsize(src):
                    return "exists", "目标已存在且大小一致, 跳过"
            except OSError:
                pass
            # 目标已存在但大小不一致(或被破坏) -> 覆盖重新推送
        dest_dir = os.path.dirname(dest)
        if dest_dir:
            os.makedirs(dest_dir, exist_ok=True)
        shutil.copy2(src, dest)
        if os.path.getsize(dest) == os.path.getsize(src):
            return "ok", ""
        return "failed", "复制后大小不一致: %s -> %s" % (src, dest)
    except Exception as e:
        return "failed", "%s" % e


def write_csv(path: str, header: list, rows: list):
    """写 CSV (UTF-8 带 BOM, Excel 直接打开中文不乱码)。"""
    with open(path, "w", encoding="utf-8-sig", newline="") as fp:
        writer = csv.writer(fp)
        writer.writerow(header)
        writer.writerows(rows)
    print("[OK] 明细已保存: %s" % path)


def main():
    _ensure_utf8_stdout()

    parser = argparse.ArgumentParser(
        description="按 md5_map.json 把文件推送到服务器共享目录, 并输出统计")
    parser.add_argument("--server_root_dir",
                        default=r"\\192.168.3.238\disk1t\files_root_dir",
                        help="服务器共享根目录, 默认 \\\\192.168.3.238\\disk1t\\files_root_dir\\")
    parser.add_argument("--files_txt", default=r"E:\output\files.txt",
                        help="files.txt 路径, 默认 E:\\output\\files.txt")
    parser.add_argument("--md5_json", default=r"E:\output\md5_map.json",
                        help="md5_map.json 路径, 默认 E:\\output\\md5_map.json")
    parser.add_argument("--user_name", default="jbl", help="服务器用户名/目录名, 默认 jbl")
    parser.add_argument("--report_dir", default=os.path.dirname(os.path.abspath(__file__)),
                        help="报告输出目录, 默认脚本所在目录")
    args = parser.parse_args()

    report_dir = args.report_dir
    os.makedirs(report_dir, exist_ok=True)

    # ---------- 1. 读取输入 ----------
    files_data = load_json(args.files_txt, "files_txt")
    md5_map = load_json(args.md5_json, "md5_map.json")

    all_files = files_data.get("all_files_dic", {})
    if not isinstance(all_files, dict) or not all_files:
        print("[ERROR] files.txt 中不存在 all_files_dic 或其为空!")
        sys.exit(1)

    # ---------- 2. 遍历 files.txt, 找 md5 并拷贝 ----------
    files_rows = []          # 每个文件的逐条结果
    md5_linked = {}          # md5 -> 该 md5 对应(任一)文件的复制结果, 供 md5_map 统计用
    copy_summary = {"ok": 0, "exists": 0, "failed": 0}
    found_cnt = 0
    not_found_cnt = 0

    print("\n===== 处理 files.txt 中的文件 =====")
    for full_path, info in all_files.items():
        if not isinstance(info, dict):
            continue
        md5 = str(info.get("md5", "")).strip()
        ue_dir = str(info.get("ue_dir", "")).strip()
        filename = str(info.get("filename", os.path.basename(ue_dir)))
        row = {
            "filename": filename,
            "ue_dir": ue_dir,
            "md5": md5,
            "found_in_map": "no",
            "copy_result": "N/A",
            "dest_path": "",
            "error": "",
        }
        if not md5:
            row["error"] = "files.txt 中该文件 md5 为空"
            not_found_cnt += 1
            files_rows.append([row[k] for k in row])
            continue

        src = md5_map.get(md5)
        if src is None:
            row["error"] = "md5_map.json 中未找到该 md5"
            not_found_cnt += 1
            files_rows.append([row[k] for k in row])
            continue

        # 找到了 md5 -> 拷贝
        found_cnt += 1
        row["found_in_map"] = "yes"
        dest = build_dest_path(args.server_root_dir, args.user_name, ue_dir)
        row["dest_path"] = dest
        status, note = copy_one(src, dest)
        row["copy_result"] = status
        row["error"] = note if status == "failed" else (
            note if status == "exists" else "")
        copy_summary[status] = copy_summary.get(status, 0) + 1
        md5_linked.setdefault(md5, status)
        files_rows.append([row[k] for k in row])

    # ---------- 3. 遍历 md5_map.json, 统计关联情况 ----------
    md5_rows = []
    linked_cnt = 0
    unlinked_cnt = 0
    for md5, src_path in md5_map.items():
        status = md5_linked.get(str(md5))
        if status is None:
            unlinked_cnt += 1
            md5_rows.append([str(md5), str(src_path), "no", "N/A", "md5_map.json 中该 md5 未被 files.txt 关联"])
        else:
            linked_cnt += 1
            note = "复制成功" if status in ("ok", "exists") else "复制失败"
            md5_rows.append([str(md5), str(src_path), "yes", status, note])

    # ---------- 4. 输出报告 ----------
    files_header = ["filename", "ue_dir", "md5", "found_in_map", "copy_result", "dest_path", "error"]
    md5_header = ["md5", "source_path", "linked", "copy_result", "note"]

    files_csv = os.path.join(report_dir, "push_report_files.csv")
    md5_csv = os.path.join(report_dir, "push_report_md5.csv")
    write_csv(files_csv, files_header, files_rows)
    write_csv(md5_csv, md5_header, md5_rows)

    total = len(all_files)
    print("\n========== 统计摘要 ==========")
    print("[files.txt] 共 %s 个文件" % total)
    print("  - 在 md5_map.json 中找到 md5: %s 个 (未找到: %s 个)"
          % (found_cnt, not_found_cnt))
    print("  - 复制成功: %s 个, 目标已存在跳过: %s 个, 复制失败: %s 个"
          % (copy_summary.get("ok", 0), copy_summary.get("exists", 0),
             copy_summary.get("failed", 0)))
    for r in files_rows:
        if r[4] == "failed":
            print("  [复制失败] %s -> %s | %s" % (r[0], r[5], r[6]))

    print("\n[md5_map.json] 共 %s 个条目" % len(md5_map))
    print("  - 被 files.txt 关联: %s 个 (未被关联: %s 个)" % (linked_cnt, unlinked_cnt))
    print("  - 关联的条目中: 复制成功/跳过: %s 个, 复制失败: %s 个"
          % (linked_cnt - sum(1 for r in md5_rows if r[3] == "failed"),
             sum(1 for r in md5_rows if r[3] == "failed")))
    for r in md5_rows:
        if r[3] == "failed":
            print("  [关联但复制失败] md5=%s src=%s | %s" % (r[0], r[1], r[4]))

    print("\n报告文件:")
    print("  - %s" % files_csv)
    print("  - %s" % md5_csv)


if __name__ == "__main__":
    main()