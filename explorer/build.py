#!/usr/bin/env python3
"""
Gera explorer/data/catalog.js a partir de um ou mais acervos de system prompts.

Uso:
  python3 explorer/build.py --source asgeirtj=/caminho/system_prompts_leaks \
                            --history asgeirtj=/caminho/clone-com-historico \
                            --source local=.

--source  NOME=PASTA   acervo a analisar (repetível)
--history NOME=PASTA   clone git com histórico (pode ser --filter=blob:none) para datas
O resultado é um arquivo JS (window.CATALOG = {...}) que o index.html carrega sem servidor.
"""
import argparse, json, os, re, subprocess, collections, datetime, hashlib

TEXT_EXT = {'.md', '.txt'}
SKIP_DIRS = {'.git', '.github', 'images', 'explorer', 'node_modules'}

VENDOR_ALIAS = {
    'anthropic': 'Anthropic', 'claude': 'Anthropic', 'openai': 'OpenAI', 'google': 'Google',
    'xai': 'xAI', 'meta': 'Meta', 'perplexity': 'Perplexity', 'perplexity.ai': 'Perplexity',
    'cursor': 'Cursor', 'mistral': 'Mistral', 'kimi': 'Kimi', 'moonshot': 'Kimi', 'deepseek': 'DeepSeek',
    'glm': 'GLM', 'chatglm4': 'GLM', 'notion': 'Notion', 'qwen': 'Qwen', 'minimax': 'MiniMax',
    'microsoft': 'Microsoft', 'pi': 'Pi', 'misc': 'Outros',
}

# Técnicas de prompt engineering detectadas por heurística (regex, case-insensitive salvo indicação)
TECHNIQUES = {
    'identidade':  r"\byou are\b|\bvocê é\b|\bas an? (ai|assistant)\b|\bknown as\b|\bpersona\b|\bidentity\b",
    'contexto':    r"knowledge cutoff|current date|today'?s date|\btimezone\b|\buser'?s location\b|\bcurrent (time|year)\b",
    'ferramentas': r"\btools?\b|\bfunction(s| call)\b|\bjson schema\b|\bparameters\b|\binvoke\b|<function|\bapi\b",
    'formatacao':  r"\bmarkdown\b|\bbullet|\bheaders?\b|\bformatting\b|\btables?\b|\blatex\b|\bcode blocks?\b",
    'seguranca':   r"\brefus|\bharmful\b|\bsafety\b|\bunsafe\b|\bcopyright|\bweapons?\b|\bself-harm\b|\bminors?\b|\billegal\b|\bdecline\b",
    'exemplos':    r"\bfor example\b|\be\.g\.|<example|\bexample:|\bexamples?\b|\bgood:|\bbad:",
    'enfase':      None,  # contado separadamente (palavras em CAIXA ALTA)
    'memoria':     r"\bmemor(y|ies)\b|\bpreferences?\b|\bpersonaliz|\buser profile\b|\bpast (chats|conversations)\b",
    'busca':       r"\bweb search\b|\bsearch results?\b|\bcit(e|ation|ations)\b|\bsources?\b|\bbrowse\b|\burls?\b",
    'raciocinio':  r"\bthink(ing)?\b|\breason(ing)?\b|\bstep[- ]by[- ]step\b|\bplan(ning)?\b|\bchain of thought\b",
    'tom':         r"\btone\b|\bconcise\b|\bverbose\b|\bwarm\b|\bfriendly\b|\bempath|\bsycophan|\bflattery\b|\bstyle\b",
    'agente':      r"\bfiles?\b|\bterminal\b|\bcommit\b|\brepository\b|\bshell\b|\bsandbox\b|\bbranch\b|\btests?\b",
}
TECH_RE = {k: re.compile(v, re.I) for k, v in TECHNIQUES.items() if v}
EMPH_RE = re.compile(r"\b(IMPORTANT|MUST|NEVER|ALWAYS|CRITICAL|DO NOT|REQUIRED|ONLY)\b")
XML_RE = re.compile(r"</([a-zA-Z_][a-zA-Z0-9_\-]{1,40})>")
HEAD_RE = re.compile(r"^(#{1,4})\s+(.+?)\s*#*\s*$", re.M)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+\.md)\)")

def kind_of(path):
    p = path.lower()
    if '/skills/' in p or p.endswith('skill.md') or '/reference/' in p or 'artifact-types' in p: return 'skill'
    if '/tools/' in p or os.path.basename(p).startswith('tool-') or '-tool' in p: return 'ferramenta'
    if re.search(r'claude-code|/codex/|cursor|gemini-cli|antigravity|muse-code|jules|devin|amp-code|warp|zed|t3-code|commandcode|grok-build|grok-4\.7-cli|windsurf|copilot|bolt|v0_|ai-studio-build|lovable|replit', p): return 'agente-codigo'
    if 'voice' in p or 'voz' in p or 'live' in os.path.basename(p): return 'voz'
    if '/old/' in p or p.startswith('old/'): return 'legado'
    if 'api' in os.path.basename(p) or '/api/' in p: return 'api'
    return 'chat'

def guess_vendor(rel, source):
    first = rel.split('/')[0]
    if '/' in rel:
        return VENDOR_ALIAS.get(first.lower(), first)
    base = os.path.basename(rel).lower()
    token = re.split(r'[-_]', base)[0]
    if token in VENDOR_ALIAS: return VENDOR_ALIAS[token]
    for k, v in VENDOR_ALIAS.items():
        if base.startswith(k): return v
    known = {'claude': 'Anthropic', 'cursor': 'Cursor', 'gemini': 'Google', 'google': 'Google',
             'github': 'Microsoft', 'microsoft': 'Microsoft', 'codeium': 'Codeium', 'xai': 'xAI',
             'discord': 'Discord', 'perplexity': 'Perplexity', 'manus': 'Manus', 'v0': 'Vercel', 'bolt.new': 'StackBlitz',
             'colab': 'Google', 'meta': 'Meta', 'mistral': 'Mistral', 'moonshot': 'Kimi', 'openai': 'OpenAI'}
    for k, v in known.items():
        if base.startswith(k): return v
    return 'Outros'

def date_from_name(name):
    m = re.search(r'(20\d{2})(\d{2})(\d{2})', name)
    if m:
        try: return datetime.date(int(m[1]), int(m[2]), int(m[3])).isoformat()
        except ValueError: return None
    return None

def git_dates(repo):
    """{path: [added, modified, ncommits]} via git log (funciona com clone blobless)."""
    out = subprocess.run(['git', '-C', repo, 'log', '--format=@%cs', '--name-only', 'HEAD'],
                         capture_output=True, text=True, check=True).stdout
    info = {}
    cur = None
    for line in out.splitlines():
        if line.startswith('@'): cur = line[1:]; continue
        if not line.strip(): continue
        d = info.setdefault(line, [cur, cur, 0])
        d[0] = cur          # log vai do mais novo ao mais velho: o último visto é a criação
        d[2] += 1
    return info

def readme_labels(root):
    """Rótulos e seções do README (prompts em destaque)."""
    labels = {}
    p = os.path.join(root, 'README.md')
    if not os.path.exists(p): return labels
    section = ''
    order = 0
    for line in open(p, encoding='utf-8', errors='replace'):
        if line.startswith('## ') or line.startswith('### '):
            section = line.strip('# \n')
            continue
        if not line.startswith('|') or section.lower().startswith('most recent'): continue
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        row_label = re.sub(r'[*\[\]]', '', cells[0]).strip() if cells else ''
        for text, href in LINK_RE.findall(line):
            href = href.split('#')[0]
            if href.startswith('http'): continue
            t = re.sub(r'\*', '', text).strip()
            if href not in labels:
                order += 1
                labels[href] = {'label': t, 'section': section, 'model': row_label, 'order': order}
    return labels

def snippet_lines(text):
    for raw in text.splitlines():
        s = raw.strip().lstrip('-*>#0123456789. ').strip()
        if 50 <= len(s) <= 260 and not s.startswith(('|', '```', '<', '{', 'http')):
            yield s

def analyze(text):
    n = max(len(text), 1)
    words = len(re.findall(r"\S+", text))
    tech = {}
    for k, rx in TECH_RE.items():
        tech[k] = len(rx.findall(text))
    emph = EMPH_RE.findall(text)
    tech['enfase'] = len(emph)
    density = {k: round(v * 10000 / n, 2) for k, v in tech.items()}
    xml = collections.Counter(XML_RE.findall(text)).most_common(8)
    heads = [(len(h), re.sub(r'[*`]', '', t)[:80]) for h, t in HEAD_RE.findall(text)][:14]
    emph_c = collections.Counter(emph).most_common(5)
    return {
        'chars': len(text), 'words': words, 'tokens': round(len(text) / 4),
        'lines': text.count('\n') + 1,
        'tech': tech, 'dens': density,
        'xml': xml, 'heads': heads, 'emph': emph_c,
        'nheads': len(HEAD_RE.findall(text)), 'nxml': len(set(XML_RE.findall(text))),
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', action='append', required=True)
    ap.add_argument('--history', action='append', default=[])
    ap.add_argument('--repo-url', action='append', default=[], help='NOME=owner/repo@branch')
    ap.add_argument('--out', default=os.path.join(os.path.dirname(__file__), 'data', 'catalog.js'))
    a = ap.parse_args()
    hist = dict(h.split('=', 1) for h in a.history)
    urls = dict(u.split('=', 1) for u in a.repo_url)

    items, sources = [], []
    tech_examples = collections.defaultdict(list)
    for spec in a.source:
        name, root = spec.split('=', 1)
        root = os.path.abspath(root)
        labels = readme_labels(root)
        dates = git_dates(hist[name]) if name in hist else (git_dates(root) if os.path.isdir(os.path.join(root, '.git')) else {})
        repo = urls.get(name, '')
        sources.append({'id': name, 'repo': repo, 'root': os.path.basename(root)})
        for dp, dns, fns in os.walk(root):
            dns[:] = [d for d in dns if d not in SKIP_DIRS]
            for fn in fns:
                ext = os.path.splitext(fn)[1].lower()
                if ext not in TEXT_EXT or fn.lower() in ('readme.md', 'license.md', 'contributing.md'): continue
                full = os.path.join(dp, fn)
                rel = os.path.relpath(full, root).replace(os.sep, '/')
                text = open(full, encoding='utf-8', errors='replace').read()
                if len(text.strip()) < 40: continue
                an = analyze(text)
                lab = labels.get(rel)
                d = dates.get(rel)
                added = (d[0] if d else None) or date_from_name(fn)
                title = lab['label'] if lab else re.sub(r'[-_]+', ' ', os.path.splitext(fn)[0]).strip()
                it = {
                    'id': hashlib.md5(f'{name}:{rel}'.encode()).hexdigest()[:10],
                    'src': name, 'path': rel, 'title': title,
                    'model': lab['model'] if lab else '', 'order': lab['order'] if lab else 0, 'section': lab['section'] if lab else '',
                    'vendor': guess_vendor(rel, name), 'kind': kind_of(rel),
                    'featured': bool(lab) or name != 'asgeirtj' and '/' not in rel,
                    'added': added, 'modified': d[1] if d else added, 'commits': d[2] if d else 0,
                    'excerpt': text.strip()[:600 if lab else 280],
                    **an,
                }
                items.append(it)
                if it['featured'] and name == 'asgeirtj':
                    for k, rx in list(TECH_RE.items()) + [('enfase', EMPH_RE)]:
                        if sum(e['vendor'] == it['vendor'] for e in tech_examples[k]) >= 2: continue
                        for s in snippet_lines(text):
                            if rx.search(s):
                                tech_examples[k].append({'id': it['id'], 'vendor': it['vendor'], 'title': it['title'], 'text': s})
                                break

    # escolhe exemplos variados por fornecedor
    examples = {}
    for k, lst in tech_examples.items():
        seen, pick = set(), []
        for e in lst:
            if e['vendor'] in seen: continue
            seen.add(e['vendor']); pick.append(e)
        for e in lst:
            if len(pick) >= 8: break
            if e not in pick: pick.append(e)
        pick = pick[:8]
        examples[k] = pick

    items.sort(key=lambda x: (not x['featured'], x['vendor'], x['path']))
    out = {
        'generated': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%MZ'),
        'sources': sources, 'techniques': list(TECHNIQUES.keys()),
        'examples': examples, 'items': items,
    }
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, 'w', encoding='utf-8') as f:
        f.write('window.CATALOG=')
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
        f.write(';\n')
    print(f'{len(items)} prompts -> {a.out} ({os.path.getsize(a.out)//1024} KB)')

if __name__ == '__main__':
    main()
