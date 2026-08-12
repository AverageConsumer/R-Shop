# -*- coding: utf-8 -*-
"""Builds docs/FIX_BY_FILE.md — a reverse index of docs/FIX_LOGS.md.

Answers "I am about to change this file; what happened here before?", which the
keyword index cannot: FIX_INDEX is organised by symptom, and you rarely know the
symptom in advance — you know the file you just opened.

Source of truth is each entry's `**檔案**` field, so this is regenerated rather
than maintained. Re-run after adding entries:  python scripts/build_fix_by_file.py

Entries written before the three-field format existed have no `**檔案**` field;
they are listed at the bottom as pending rather than dropped, so the gap stays
visible.
"""
import io, os, re, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGS = os.path.join(ROOT, 'docs', 'FIX_LOGS.md')
OUT = os.path.join(ROOT, 'docs', 'FIX_BY_FILE.md')

text = io.open(LOGS, encoding='utf-8').read()
entries = re.split(r'^## \[', text, flags=re.M)[1:]

by_file = collections.defaultdict(list)
pending = []
for e in entries:
    key = e.split(']', 1)[0]
    body = e.split('\n', 1)[1] if '\n' in e else ''
    # The 檔案 field runs until the next bullet that is not a continuation line.
    m = re.search(r'^- \*\*檔案\*\*：(.*?)(?=^\s*$|^- \*\*(?!檔案))', body, re.M | re.S)
    if not m:
        pending.append(key)
        continue
    block = m.group(1)
    paths = re.findall(r'`([^`]+?)`', block)
    paths = [p for p in paths if '/' in p or p.endswith('.sh') or p.endswith('.md')]
    if not paths:
        pending.append(key)
    for p in paths:
        p = p.split(':')[0].strip()
        if key not in by_file[p]:
            by_file[p].append(key)

lines = [
    '# R-Shop 檔案 → 紀錄 反查表',
    '',
    '> **自動產生，不要手改。** 來源是 [FIX_LOGS.md](FIX_LOGS.md) 每條的 `**檔案**` 欄。',
    '> 新增紀錄後重跑：`python scripts/build_fix_by_file.py`',
    '>',
    '> 用途與 [FIX_INDEX.md](FIX_INDEX.md) 相反：索引是「症狀 → 條目」，這裡是',
    '> **「我要改這個檔 → 它身上以前發生過什麼」**。改檔案前先查這裡，',
    '> 命中的條目多半就是會再踩一次的坑。',
    '',
]
for path in sorted(by_file):
    keys = by_file[path]
    lines.append('### `%s`' % path)
    for k in keys:
        lines.append('- [%s](FIX_LOGS.md)' % k)
    lines.append('')

if pending:
    lines.append('---')
    lines.append('')
    lines.append('## 尚未指明檔案的條目')
    lines.append('')
    # 這一段常被讀成「有東西漏寫了」，但多數其實是環境診斷、部署作業、需求判定
    # 這類本來就沒動到檔案的紀錄——它們在反查表上無處可去是正確的，不要為了讓
    # 數字歸零去編假路徑。只有「待補」才是真的欠。見 FIX_LOGS 的 [R-Shop 反查不到]。
    lines.append('這些條目沒有可反查的檔案。**多數是正確狀態**——環境診斷、部署作業、'
                 '需求判定本來就沒有程式碼變更，`**檔案**` 欄寫的是「無程式碼變更」。')
    lines.append('')
    lines.append('只有標成「待補」的才是真的欠一份說明。')
    lines.append('')
    for k in pending:
        lines.append('- %s' % k)
    lines.append('')

io.open(OUT, 'w', encoding='utf-8', newline='').write('\n'.join(lines))
print('files: %d   entries without paths: %d' % (len(by_file), len(pending)))
