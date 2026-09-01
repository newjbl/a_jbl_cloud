#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
merger_server_files.py
将 inputdir 下的所有文件按 MD5 去重后移动到 outputdir：

  1. 递归扫描 inputdir 下所有文件；
  2. 每个文件计算 MD5（与 server/server.py 中 caculate_md5() 算法完全一致：
     hashlib.md5() + 按 8192 字节分块读取 + hexdigest()）；
  3. 相同 MD5 的文件只移动一个：优先保留不带 "(1)" 之类括号序号后缀的原始文件名
     （例如 XXXX.PNG 与 XXXX(1).PNG 的 MD5 相同，只移动 XXXX.PNG）；
  4. 输出字典 {MD5: 移动后的文件路径}，并默认保存为 outputdir/md5_map.json。

用法：
    python merger_server_files.py <inputdir> <outputdir> [--json 保存路径]
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import sys

# 与 server/server.py 中的 caculate_md5() 保持一致的算法
def caculate_md5(filepath):
    if not os.path.exists(filepath):
        return ""
    md5 = hashlib.md5()
    with open(filepath, "rb") as f:
        while chunk := f.read(8192):
            md5.update(chunk)
    return md5.hexdigest()


def has_index_suffix(filename):
    """文件名主干是否带 (数字) 后缀，如 XXXX(1).PNG -> True"""
    stem, _ext = os.path.splitext(filename)
    return bool(re.search(r"\(\d+\)$", stem))


def scan_files(inputdir):
    """递归扫描 inputdir 下所有文件，返回绝对路径列表（顺序确定，便于复现）"""
    files = []
    for root, _dirs, names in os.walk(inputdir):
        for name in sorted(names):
            files.append(os.path.join(root, name))
    return files


def unique_dest_path(outputdir, filename):
    """outputdir 下若已存在同名文件，自动追加 (n) 避免覆盖"""
    dest = os.path.join(outputdir, filename)
    stem, ext = os.path.splitext(filename)
    n = 1
    while os.path.exists(dest):
        dest = os.path.join(outputdir, "{}({}){}".format(stem, n, ext))
        n += 1
    return dest


def main():

    inputdir = r'E:\华为云空间'
    outputdir = r'E:\output'
    files = scan_files(inputdir)
    if not files:
        print("警告：inputdir 下没有找到任何文件: {}".format(inputdir), file=sys.stderr)
        return 1

    # ---- 第一遍：计算所有文件的 MD5，按 MD5 分组 ----
    # 每组元素: (优先级, 目录深度, 文件绝对路径)
    # 优先级 0 = 原始文件名(无括号序号后缀)，优先移动；1 = 带 (N) 后缀
    md5_groups = {}
    for idx, f in enumerate(files):
        if idx % 100 == 0:
            print("{}%".format(idx / len(files) * 100), file=sys.stderr)
        md5 = caculate_md5(f)
        if not md5:
            print("跳过无法计算 MD5 的文件: {}".format(f), file=sys.stderr)
            continue
        filename = os.path.basename(f)
        priority = 1 if has_index_suffix(filename) else 0
        depth = len(os.path.relpath(f, inputdir).split(os.sep))
        md5_groups.setdefault(md5, []).append((priority, depth, f))

    # ---- 第二遍：每个 MD5 只移动一个文件（优先级最高者），其余跳过 ----
    result = {}  # {MD5: 移动后的文件路径}
    for md5, cands in sorted(md5_groups.items()):
        cands.sort(key=lambda item: (item[0], item[1], item[2]))
        chosen = cands[0][2]
        dest = unique_dest_path(outputdir, os.path.basename(chosen))
        shutil.move(chosen, dest)
        result[md5] = os.path.abspath(dest)
        print("[OK] {} -> {}".format(chosen, dest))
        if len(cands) > 1:
            dropped = ", ".join(item[2] for item in cands[1:])
            print("     MD5 重复，跳过 {}/{} 个: {}".format(len(cands) - 1, len(cands), dropped))

    # ---- 输出字典 ----
    print("\n== 结果字典 (MD5 -> 移动后的文件路径) ==")
    print(json.dumps(result, indent=2, ensure_ascii=False))

    json_path = os.path.join(outputdir, "md5_map.json")
    with open(json_path, "w", encoding="utf-8") as fp:
        json.dump(result, fp, indent=2, ensure_ascii=False)
    print("\n字典已保存到: {}".format(os.path.abspath(json_path)))
    print("共移动 {} 个文件（原 {} 个文件，去重 {} 个）".format(
        len(result), len(files), len(files) - len(result)))
    return 0


if __name__ == "__main__":
    main()