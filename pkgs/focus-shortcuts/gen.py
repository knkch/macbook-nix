# 集中モードの切り替え用ショートカット（署名前）を作る。
# 引数: <モード一覧の JSON> <出力先>
# 出力先には <番号>-on.shortcut / <番号>-off.shortcut と、
# manifest.tsv（1 行 1 個: ファイル名 TAB ショートカットの名前）を置く。
import json
import os
import plistlib
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    modes = json.load(f)
out = sys.argv[2]
os.makedirs(out)

lines = []
for i, mode in enumerate(modes):
    for on in (True, False):
        # 「集中モードを設定」アクション。モードは識別子で指定し、オンは Enabled: 1、オフは指定なし
        params = {"FocusModes": {"Identifier": mode["id"], "DisplayString": mode["display"]}}
        if on:
            params["Enabled"] = 1
        workflow = {
            "WFWorkflowActions": [
                {"WFWorkflowActionIdentifier": "is.workflow.actions.dnd.set",
                 "WFWorkflowActionParameters": params}
            ],
            "WFWorkflowClientVersion": "2607.0.2",
            "WFWorkflowIcon": {"WFWorkflowIconStartColor": 1440408063, "WFWorkflowIconGlyphNumber": 59446},
            "WFWorkflowImportQuestions": [],
            "WFWorkflowInputContentItemClasses": [],
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowTypes": [],
            "WFWorkflowHasShortcutInputVariables": False,
        }
        file = f"{i}-{'on' if on else 'off'}.shortcut"
        with open(os.path.join(out, file), "wb") as f:
            plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
        lines.append(f"{file}\t集中モード: {mode['name']} {'オン' if on else 'オフ'}")

with open(os.path.join(out, "manifest.tsv"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
