"""Generate os_contract_templates_seed.dart from point_os/contractsData.ts."""
import re
from pathlib import Path

TS = Path(r"D:\point_os\contractsData.ts")
OUT = Path(r"D:\point\lib\Data\os_contract_templates_seed.dart")

ts = TS.read_text(encoding="utf-8")
template_ids = re.findall(r"id: '(TPL-[^']+)'", ts)

CAT_MAP = {
    "CLIENT": "client",
    "EMPLOYEE": "employee",
    "FREELANCER": "freelancer",
}


def extract_template(tpl_id: str) -> str:
    pat = rf"\{{\s*id: '{tpl_id}'"
    m = re.search(pat, ts)
    if not m:
        return ""
    start = m.start()
    next_ids = [ts.find(f"id: '{tid}'", start + 1) for tid in template_ids if tid != tpl_id]
    next_ids = [x for x in next_ids if x > start]
    end = min(next_ids) if next_ids else ts.find("];", start)
    return ts[start:end]


def parse_field(block: str, field: str):
    m = re.search(rf"{field}: '([^']*)'", block)
    if m:
        return m.group(1)
    m = re.search(rf"{field}: (\d+)", block)
    if m:
        return int(m.group(1))
    return None


def parse_clauses(block: str):
    clauses = []
    parts = re.split(r"\{\s*id: 'c-", block)
    for part in parts[1:]:
        cid_m = re.match(r"([^']+)'", part)
        if not cid_m:
            continue
        cid = "c-" + cid_m.group(1)
        title_m = re.search(r"title: '([^']*)'", part)
        mandatory_m = re.search(r"isMandatory: (true|false)", part)
        content_m = re.search(r"content: `([\s\S]*?)`\s*,?\s*\n\s*\}", part)
        if not title_m or not content_m:
            continue
        clauses.append(
            {
                "id": cid,
                "title": title_m.group(1),
                "mandatory": mandatory_m.group(1) == "true" if mandatory_m else False,
                "content": content_m.group(1).strip(),
            }
        )
    return clauses


def dart_triple(s: str) -> str:
    return "'''" + s.replace("'''", r"''\'''") + "'''"


lines: list[str] = [
    "import 'package:point/Models/Os/OsContractClause.dart';",
    "import 'package:point/Models/Os/OsContractTemplate.dart';",
    "import 'package:point/Models/Os/os_legal_contract_enums.dart';",
    "",
    "/// Preset legal contract templates ported from point_os `contractsData.ts`.",
    "class OsContractTemplatesSeed {",
    "  OsContractTemplatesSeed._();",
    "",
    "  static List<OsContractTemplate> presets() => [",
]

def parse_tags(block: str):
    m = re.search(r"tags: \[(.*?)\]", block, re.DOTALL)
    if not m:
        return []
    return re.findall(r"'([^']*)'", m.group(1))


for tpl_id in template_ids:
    block = extract_template(tpl_id)
    title = parse_field(block, "title") or ""
    category = parse_field(block, "category") or "CLIENT"
    sub_type = parse_field(block, "subType") or ""
    governing_law = parse_field(block, "governingLaw") or ""
    desc = parse_field(block, "description") or ""
    months = parse_field(block, "defaultDurationMonths")
    tags = parse_tags(block)
    clauses = parse_clauses(block)
    target = f"OsLegalContractTargetType.{CAT_MAP.get(category, 'client')}"
    name = re.sub(r"\s*\([^)]*\)\s*$", "", title).strip()

    lines.append("        OsContractTemplate(")
    lines.append(f"          id: '{tpl_id}',")
    lines.append(f"          name: {dart_triple(name)},")
    lines.append(f"          description: {dart_triple(desc)},")
    lines.append(f"          targetType: {target},")
    lines.append(f"          suggestedTitle: {dart_triple(title)},")
    if sub_type:
        lines.append(f"          subType: {dart_triple(sub_type)},")
    if governing_law:
        lines.append(f"          governingLaw: {dart_triple(governing_law)},")
    if tags:
        tag_items = ", ".join(dart_triple(t) for t in tags)
        lines.append(f"          tags: [{tag_items}],")
    if months:
        lines.append(f"          defaultDurationMonths: {months},")
    lines.append("          clauses: [")
    for c in clauses:
        lines.extend(
            [
                "            OsContractClause(",
                f"              id: '{c['id']}',",
                f"              title: {dart_triple(c['title'])},",
                f"              isMandatory: {str(c['mandatory']).lower()},",
                f"              content: {dart_triple(c['content'])},",
                "            ),",
            ]
        )
    lines.append("          ],")
    lines.append("        ),")

lines.extend(
    [
        "      ];",
        "",
        "  static OsContractTemplate? byId(String? id) {",
        "    if (id == null || id.isEmpty) return null;",
        "    for (final t in presets()) {",
        "      if (t.id == id) return t;",
        "    }",
        "    return null;",
        "  }",
        "}",
    ]
)

OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
total_clauses = sum(len(parse_clauses(extract_template(t))) for t in template_ids)
print(f"Wrote {OUT} ({len(template_ids)} templates, {total_clauses} clauses)")
