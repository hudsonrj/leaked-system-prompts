"""Gera ../Cronograma_HAT_Vale_CDI.xlsx (v2: agentes, entregas e linguagem simples).
Uso: python3 build_xlsx.py <pasta_fonte> <raiz_do_pacote>
responsaveis_status.json guarda colunas editadas à mão (responsável sugerido, status)."""
import sys, json, datetime as dt
SRC = sys.argv[1]; OUT = sys.argv[2]; sys.path.insert(0, SRC)
from tasks import T, T2, T3, SOL_DIFF, SOL_PRED
from solicitacoes import SOL
from human import ENTREGAS, AGENTES, H, SOLH
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.formatting.rule import FormulaRule, CellIsRule
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.utils import get_column_letter as L

USER = json.load(open(f"{SRC}/responsaveis_status.json", encoding="utf-8"))
START = dt.date(2026, 11, 30)
HOL = [dt.date(2026,12,24),dt.date(2026,12,25),dt.date(2026,12,31),dt.date(2027,1,1),
       dt.date(2027,2,8),dt.date(2027,2,9),dt.date(2027,3,26),dt.date(2027,4,21)]
HOLN = ["Véspera de Natal (recesso)","Natal","Véspera de Ano-Novo (recesso)","Confraternização Universal","Carnaval","Carnaval","Sexta-feira Santa","Tiradentes"]
def isw(d): return d.weekday() < 5 and d not in HOL
def nextw(d):
    d += dt.timedelta(1)
    while not isw(d): d += dt.timedelta(1)
    return d
def firstw(d):
    while not isw(d): d += dt.timedelta(1)
    return d
def addw(d, n):
    for _ in range(n - 1): d = nextw(d)
    return d

# ---------- tarefas ----------
sol_tasks = []
for s in SOL:
    preds = ["J00"] + SOL_PRED.get(s[0], [])
    if s[0] in ("SOL-SEG-04", "SOL-OPS-02", "SOL-SEG-01"): preds = SOL_PRED[s[0]]
    tech = f"{s[3]} — Pronto quando: {s[7]}".replace("**", "").replace("`", "")
    sol_tasks.append((s[0], "J. Solicitações Vale", s[2], tech, f"Vale — {s[5]}", SOL_DIFF[s[0]], 0.5, s[6], preds))
ALL = T + T2 + sol_tasks + T3
byid = {t[0]: t for t in ALL}
sched = {}
def sch(i):
    if i in sched: return sched[i]
    t = byid[i]; p = t[8]
    s = firstw(START) if not p else (max(sch(x)[1] for x in p) if t[7] == 0 else nextw(max(sch(x)[1] for x in p)))
    e = s if t[7] == 0 else addw(s, t[7])
    sched[i] = (s, e); return s, e
for t in ALL: sch(t[0])
proj_end = max(e for s, e in sched.values())

def human(t):
    i = t[0]
    if i.startswith("SOL-"):
        s = next(x for x in SOL if x[0] == i)
        ag, titulo = SOLH[i]
        return "ENT-10", ag, titulo, s[4].replace("**", "").replace("`", "")
    return H[i]

ENT = {e[0]: e for e in ENTREGAS}
grupos = {e[0]: [] for e in ENTREGAS}
for t in ALL: grupos[human(t)[0]].append(t)
for k in grupos: grupos[k].sort(key=lambda t: (sched[t[0]][0], t[0]))

# ---------- estilos ----------
wb = Workbook()
GREEN = "0B3D2E"; LG = "E8F1EC"; ENTF = PatternFill("solid", fgColor="CFE3D8")
thin = Side(style="thin", color="C8D3CD"); B = Border(left=thin, right=thin, top=thin, bottom=thin)
HF = PatternFill("solid", fgColor=GREEN); HFont = Font(bold=True, color="FFFFFF")
DIFF = {"Baixa": "D4EDDA", "Média": "FFF3CD", "Alta": "F8D7DA", "Muito alta": "E3B7EB"}
AGF = {"A1": "DCE9F7", "A2": "FCE4D6", "A3": "E2EFDA", "A4": "EDE2F6", "Todos": "F2F2F2", "Gestão": "FFF9E5"}
def head(ws, row, cols, start=1):
    for i, h in enumerate(cols, start):
        c = ws.cell(row, i, h); c.font = HFont; c.fill = HF; c.border = B
        c.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
def agfill(ag):
    k = ag.split(",")[0].strip()
    return PatternFill("solid", fgColor=AGF.get(k if "," not in ag else "Todos", "F2F2F2")) if "," not in ag else PatternFill("solid", fgColor="FFFFFF")

# ---------- Feriados ----------
wf = wb.active; wf.title = "Feriados"
head(wf, 1, ["Data", "Descrição"])
for k, (d, n) in enumerate(zip(HOL, HOLN), 2):
    wf.cell(k, 1, d).number_format = "dd/mm/yyyy"; wf.cell(k, 2, n)
wf.column_dimensions["A"].width = 14; wf.column_dimensions["B"].width = 34

# ---------- Cronograma ----------
ws = wb.create_sheet("Cronograma", 0)
ws["A1"] = "Cronograma — Ambiente HAT, pacote Vale e implantação Core Data Integration"
ws["A1"].font = Font(bold=True, size=14, color=GREEN)
ws["A2"] = (f"Início: {START:%d/%m/%Y} · Término previsto: {proj_end:%d/%m/%Y} · Tarefas agrupadas por ENTREGA "
            "(linhas verdes; use os botões +/− à esquerda para abrir/fechar). Coluna 'Agente(s)' mostra qual agente cada tarefa habilita. "
            "Fim = DIATRABALHO(Início; Duração−1; Feriados).")
ws["A2"].font = Font(italic=True, size=9)
ws["A3"] = "Primeira Versao: Hudson Santos / 25/11/2026"
hdr = ["ID", "Entrega (o todo)", "Agente(s)", "Tarefa", "O que é / resultado esperado", "Categoria", "Responsável (papel)",
       "Responsável sugerido", "Dificuldade", "Esforço (dias-pessoa)", "Duração (dias úteis)", "Predecessoras",
       "Início", "Fim", "Status", "Mês do projeto", "Detalhe técnico"]
C = {h: i for i, h in enumerate(hdr, 1)}
cS, cE, cDur, cEsf, cSt, cAg, cDif = [L(C[x]) for x in ["Início", "Fim", "Duração (dias úteis)", "Esforço (dias-pessoa)", "Status", "Agente(s)", "Dificuldade"]]
HR = 5
head(ws, HR, hdr)
weeks = []; w = START - dt.timedelta(START.weekday())
while w <= proj_end: weeks.append(w); w += dt.timedelta(7)
G0 = len(hdr) + 1
for j, wk in enumerate(weeks):
    c = ws.cell(HR, G0 + j, wk); c.number_format = "dd/mm"; c.font = Font(bold=True, color="FFFFFF", size=8); c.fill = HF
    c.alignment = Alignment(text_rotation=90, horizontal="center"); ws.column_dimensions[L(G0 + j)].width = 3.2
    m = ws.cell(HR - 1, G0 + j, f"S{j+1}"); m.font = Font(size=7, color="666666"); m.alignment = Alignment(horizontal="center")
def mes(d): return f"Mês {min((d - START).days // 30 + 1, 6)}"

r = HR + 1; first = r; ent_rows = {}
for e in ENTREGAS:
    tasks = grupos[e[0]]
    if not tasks: continue
    er = r; a, b = er + 1, er + len(tasks)
    ent_rows[e[0]] = (er, a, b)
    vals = {"ID": e[0], "Entrega (o todo)": e[1], "Agente(s)": e[2], "Tarefa": e[1].upper(),
            "O que é / resultado esperado": f"{e[3]} Pronto quando: {e[4]}",
            "Esforço (dias-pessoa)": f"=SUM({cEsf}{a}:{cEsf}{b})",
            "Início": f"=MIN({cS}{a}:{cS}{b})", "Fim": f"=MAX({cE}{a}:{cE}{b})",
            "Duração (dias úteis)": f"=NETWORKDAYS({cS}{er},{cE}{er},Feriados!$A$2:$A$50)",
            "Status": f'=COUNTIF({cSt}{a}:{cSt}{b},"Concluído")&" de "&ROWS({cSt}{a}:{cSt}{b})&" concluídas"',
            "Mês do projeto": f"{len(tasks)} tarefas"}
    for h, i in C.items():
        c = ws.cell(er, i, vals.get(h)); c.fill = ENTF; c.border = B; c.font = Font(bold=True, color=GREEN)
        c.alignment = Alignment(wrap_text=h in ("Tarefa", "O que é / resultado esperado"), vertical="top")
    ws.cell(er, C["Início"]).number_format = ws.cell(er, C["Fim"]).number_format = "dd/mm/yyyy"
    r += 1
    for t in tasks:
        ent, ag, tarefa, oque = human(t)
        s0, _ = sched[t[0]]; u = USER.get(t[0], {})
        tech = u.get("desc") or t[3]
        vals = {"ID": t[0], "Entrega (o todo)": e[1], "Agente(s)": ag, "Tarefa": tarefa, "O que é / resultado esperado": oque,
                "Categoria": t[1], "Responsável (papel)": t[4], "Responsável sugerido": u.get("resp_sug"),
                "Dificuldade": t[5], "Esforço (dias-pessoa)": t[6], "Duração (dias úteis)": t[7],
                "Predecessoras": ", ".join(t[8]), "Início": s0,
                "Fim": f"=IF({cDur}{r}=0,{cS}{r},WORKDAY({cS}{r},{cDur}{r}-1,Feriados!$A$2:$A$50))",
                "Status": u.get("status") or "Não iniciado", "Mês do projeto": mes(s0), "Detalhe técnico": tech}
        for h, i in C.items():
            c = ws.cell(r, i, vals[h]); c.border = B
            c.alignment = Alignment(wrap_text=h in ("Tarefa", "O que é / resultado esperado", "Predecessoras", "Detalhe técnico", "Entrega (o todo)"), vertical="top")
        ws.cell(r, C["Início"]).number_format = ws.cell(r, C["Fim"]).number_format = "dd/mm/yyyy"
        ws.cell(r, C["Dificuldade"]).fill = PatternFill("solid", fgColor=DIFF[t[5]])
        ws.cell(r, C["Agente(s)"]).fill = agfill(ag)
        if t[7] == 0:
            for i in range(1, len(hdr) + 1): ws.cell(r, i).font = Font(bold=True, color=GREEN)
        ws.row_dimensions[r].outlineLevel = 1
        r += 1
last = r - 1
ws.sheet_properties.outlinePr.summaryBelow = False
widths = {"ID": 11, "Entrega (o todo)": 22, "Agente(s)": 12, "Tarefa": 40, "O que é / resultado esperado": 58, "Categoria": 18,
          "Responsável (papel)": 20, "Responsável sugerido": 16, "Dificuldade": 11, "Esforço (dias-pessoa)": 9,
          "Duração (dias úteis)": 9, "Predecessoras": 16, "Início": 11, "Fim": 11, "Status": 17, "Mês do projeto": 10, "Detalhe técnico": 60}
for h, wd in widths.items(): ws.column_dimensions[L(C[h])].width = wd
# colunas técnicas recolhíveis (Categoria, Responsável papel, Predecessoras, Detalhe técnico)
for h in ["Categoria", "Detalhe técnico"]:
    ws.column_dimensions[L(C[h])].outlineLevel = 1; ws.column_dimensions[L(C[h])].hidden = True
ws.freeze_panes = ws.cell(HR + 1, C["Tarefa"] + 1)
ws.auto_filter.ref = f"A{HR}:{L(len(hdr))}{last}"
gl, gr = L(G0), L(G0 + len(weeks) - 1)
rng = f"{gl}{first}:{gr}{last}"
wk = f"{gl}${HR}"
ws.conditional_formatting.add(rng, FormulaRule(formula=[f'AND(LEFT($A{first},4)="ENT-",${cS}{first}<={wk}+6,${cE}{first}>={wk})'], fill=PatternFill("solid", fgColor="7FB89A"), stopIfTrue=True))
ws.conditional_formatting.add(rng, FormulaRule(formula=[f'AND(${cDur}{first}=0,${cS}{first}>={wk},${cS}{first}<={wk}+6)'], fill=PatternFill("solid", fgColor="C9A227"), stopIfTrue=True))
ws.conditional_formatting.add(rng, FormulaRule(formula=[f'AND(LEFT(${L(C["Responsável (papel)"])}{first},4)="Vale",${cS}{first}<={wk}+6,${cE}{first}>={wk})'], fill=PatternFill("solid", fgColor="9BB7D4"), stopIfTrue=True))
ws.conditional_formatting.add(rng, FormulaRule(formula=[f'AND(${cS}{first}<={wk}+6,${cE}{first}>={wk})'], fill=PatternFill("solid", fgColor="2E8B57")))
for rr in range(first, last + 1):
    for j in range(len(weeks)): ws.cell(rr, G0 + j).border = B
dv = DataValidation(type="list", formula1='"Não iniciado,Em andamento,Bloqueado,Concluído,Cancelado"', allow_blank=True)
ws.add_data_validation(dv)
for e, (er, a, b) in ent_rows.items(): dv.add(f"{cSt}{a}:{cSt}{b}")
for txt, col in [("Concluído", "D4EDDA"), ("Bloqueado", "F8D7DA"), ("Em andamento", "FFF3CD")]:
    ws.conditional_formatting.add(f"{cSt}{first}:{cSt}{last}", CellIsRule(operator="equal", formula=[f'"{txt}"'], fill=PatternFill("solid", fgColor=col)))
CR = f"Cronograma!${cDif}:${cDif}"  # critério "linha é tarefa" = dificuldade preenchida
def rngc(h): return f"Cronograma!${L(C[h])}:${L(C[h])}"

# ---------- Entregas e agentes ----------
we = wb.create_sheet("Entregas e agentes", 1)
we["A1"] = "Entregas (o 'todo') e os agentes que cada uma habilita"; we["A1"].font = Font(bold=True, size=14, color=GREEN)
we["A2"] = "Números contam tarefas da aba Cronograma. Uma tarefa marcada 'Todos' serve a todos os agentes e entra em todas as colunas A1–A4."
we["A2"].font = Font(italic=True, size=9)
eh = ["Entrega", "Nome", "Para que serve", "Pronto quando", "Tarefas", "Concluídas", "% concluído", "Início", "Fim",
      "A1", "A2", "A3", "A4", "Só gestão"]
head(we, 4, eh)
for k, e in enumerate(ENTREGAS, 5):
    if e[0] not in ent_rows: continue
    er, a, b = ent_rows[e[0]]
    span = lambda col: f"Cronograma!{col}{a}:{col}{b}"
    vals = [e[0], e[1], e[3], e[4], f"=ROWS({span(cSt)})", f'=COUNTIF({span(cSt)},"Concluído")', f"=IFERROR(F{k}/E{k},0)",
            f"=Cronograma!{cS}{er}", f"=Cronograma!{cE}{er}"]
    for ag in ["A1", "A2", "A3", "A4"]:
        vals.append(f'=COUNTIF({span(cAg)},"*{ag}*")+COUNTIF({span(cAg)},"Todos")')
    vals.append(f'=COUNTIF({span(cAg)},"Gestão")')
    for i, v in enumerate(vals, 1):
        c = we.cell(k, i, v); c.border = B; c.alignment = Alignment(wrap_text=i in (2, 3, 4), vertical="top")
    we.cell(k, 7).number_format = "0%"; we.cell(k, 8).number_format = we.cell(k, 9).number_format = "dd/mm/yyyy"
    for i, ag in enumerate(["A1", "A2", "A3", "A4"], 10): we.cell(k, i).fill = PatternFill("solid", fgColor=AGF[ag])
from openpyxl.formatting.rule import DataBarRule
we.conditional_formatting.add(f"G5:G{4+len(ENTREGAS)}", DataBarRule(start_type="num", start_value=0, end_type="num", end_value=1, color="2E8B57"))
for i, wd in enumerate([8, 30, 50, 44, 8, 10, 10, 11, 11, 6, 6, 6, 6, 8], 1): we.column_dimensions[L(i)].width = wd
k = 6 + len(ENTREGAS)
we.cell(k, 1, "Os agentes").font = Font(bold=True, size=13, color=GREEN); k += 1
ah = ["Agente", "Nome", "O que ele faz (em uma frase)", "Tarefas exclusivas ou compartilhadas", "Tarefas da fundação comum",
      "Tudo de que ele depende fica pronto em", "Entregas de que depende"]
head(we, k, ah); k += 1
for ag in AGENTES:
    code = ag[0]
    if code in ("A1", "A2", "A3", "A4"):
        own = f'=COUNTIFS({rngc("Agente(s)")},"*{code}*",{CR},"<>")'
        allt = f'=COUNTIFS({rngc("Agente(s)")},"Todos",{CR},"<>")'
        ready = f'=MAX(_xlfn.MAXIFS({rngc("Fim")},{rngc("Agente(s)")},"*{code}*",{CR},"<>"),_xlfn.MAXIFS({rngc("Fim")},{rngc("Agente(s)")},"Todos",{CR},"<>"))'
        deps = ", ".join(e[0] for e in ENTREGAS if any((code in human(t)[1]) or human(t)[1] == "Todos" for t in grupos[e[0]]))
    else:
        own = f'=COUNTIFS({rngc("Agente(s)")},"{code}",{CR},"<>")'; allt = "—"
        ready = f'=_xlfn.MAXIFS({rngc("Fim")},{rngc("Agente(s)")},"{code}",{CR},"<>")'; deps = "—"
    for i, v in enumerate([code, ag[1], ag[2], own, allt, ready, deps], 1):
        c = we.cell(k, i, v); c.border = B; c.alignment = Alignment(wrap_text=i in (2, 3, 7), vertical="top")
    we.cell(k, 1).fill = PatternFill("solid", fgColor=AGF[code]); we.cell(k, 6).number_format = "dd/mm/yyyy"
    k += 1
k += 1
we.cell(k, 1, "Tarefas específicas de cada agente").font = Font(bold=True, size=13, color=GREEN); k += 1
head(we, k, ["Agente", "ID", "Tarefa", "Entrega", "Início", "Fim"]); k += 1
for code in ["A1", "A2", "A3", "A4"]:
    for t in sorted(ALL, key=lambda t: sched[t[0]][0]):
        ent, ag, tarefa, _ = human(t)
        if code in ag:
            for i, v in enumerate([code, t[0], tarefa, f"{ent} · {ENT[ent][1]}", sched[t[0]][0], sched[t[0]][1]], 1):
                c = we.cell(k, i, v); c.border = B; c.alignment = Alignment(wrap_text=i in (3, 4), vertical="top")
            we.cell(k, 1).fill = PatternFill("solid", fgColor=AGF[code])
            we.cell(k, 5).number_format = we.cell(k, 6).number_format = "dd/mm/yyyy"
            k += 1
we.freeze_panes = "C5"

# ---------- Solicitações Vale ----------
wv = wb.create_sheet("Solicitações Vale", 2)
hv = ["ID", "Pedido em linguagem simples", "Agentes beneficiados", "Categoria", "Solicitação (título técnico)", "O que solicitamos",
      "Justificativa (arquitetura)", "Responsável Vale", "Prioridade", "Dificuldade", "Lead time (d.u.)", "Bloqueia",
      "Critério de pronto", "Data envio", "Previsão (envio + lead time)", "Status", "Nº chamado Vale", "Observações"]
head(wv, 1, hv)
for k, s in enumerate(SOL, 2):
    ag, titulo = SOLH[s[0]]
    vals = [s[0], titulo, ag, s[1], s[2], s[3].replace("**", "").replace("`", ""), s[4].replace("**", "").replace("`", ""), s[5], s[9],
            SOL_DIFF[s[0]], s[6], s[8], s[7], sched[s[0]][0], f"=WORKDAY(N{k},K{k},Feriados!$A$2:$A$50)", "A enviar", "", ""]
    for i, v in enumerate(vals, 1):
        c = wv.cell(k, i, v); c.border = B; c.alignment = Alignment(wrap_text=True, vertical="top")
    wv.cell(k, 14).number_format = wv.cell(k, 15).number_format = "dd/mm/yyyy"
    wv.cell(k, 10).fill = PatternFill("solid", fgColor=DIFF[SOL_DIFF[s[0]]])
    wv.cell(k, 3).fill = agfill(ag)
    if s[9] == "Crítica": wv.cell(k, 9).fill = PatternFill("solid", fgColor="F8D7DA")
    elif s[9] == "Alta": wv.cell(k, 9).fill = PatternFill("solid", fgColor="FFF3CD")
lv = len(SOL) + 1
for i, wd in enumerate([11, 34, 14, 13, 30, 55, 42, 22, 10, 11, 9, 16, 32, 11, 12, 13, 14, 22], 1): wv.column_dimensions[L(i)].width = wd
dv2 = DataValidation(type="list", formula1='"A enviar,Enviado,Em análise,Aprovado,Implementado,Validado (HAT),Recusado"', allow_blank=True)
wv.add_data_validation(dv2); dv2.add(f"P2:P{lv}")
wv.freeze_panes = "C2"; wv.auto_filter.ref = f"A1:R{lv}"

# ---------- Resumo ----------
wr = wb.create_sheet("Resumo", 0)
wr["A1"] = "Core Data Integration — Ambiente Azure HAT ⇄ Vale"; wr["A1"].font = Font(bold=True, size=16, color=GREEN)
wr["A2"] = "Roteiro, pedidos à Vale e implantação — organizado por entregas e por agente"; wr["A2"].font = Font(italic=True)
wr["A3"] = "Primeira Versao: Hudson Santos / 25/11/2026"; wr["A3"].font = Font(size=9, color="666666")
info = [("Início", START), ("Término previsto", proj_end), ("Total de tarefas", len(ALL)), ("Entregas", len(ENTREGAS)),
        ("Pedidos à Vale", len(SOL)), ("Esforço HAT estimado (dias-pessoa)", f'=SUMIFS({rngc("Esforço (dias-pessoa)")},{rngc("Responsável (papel)")},"<>Vale*",{CR},"<>")')]
r = 5
for k_, v in info:
    wr.cell(r, 1, k_).font = Font(bold=True); c = wr.cell(r, 2, v)
    if isinstance(v, dt.date): c.number_format = "dd/mm/yyyy"
    r += 1
r += 1
wr.cell(r, 1, "Entregas — o que vamos entregar e quando").font = Font(bold=True, size=12, color=GREEN); r += 1
head(wr, r, ["Entrega", "Agentes", "Tarefas", "Início", "Fim", "% concluído"]); r += 1
for k, e in enumerate(ENTREGAS, 5):
    if e[0] not in ent_rows: continue
    vals = [f"{e[0]} · {e[1]}", e[2], f"='Entregas e agentes'!E{k}", f"='Entregas e agentes'!H{k}", f"='Entregas e agentes'!I{k}", f"='Entregas e agentes'!G{k}"]
    for i, v in enumerate(vals, 1):
        c = wr.cell(r, i, v); c.border = B
    wr.cell(r, 4).number_format = wr.cell(r, 5).number_format = "dd/mm/yyyy"; wr.cell(r, 6).number_format = "0%"
    r += 1
r += 1
wr.cell(r, 1, "Tarefas por categoria e dificuldade").font = Font(bold=True, size=12, color=GREEN); r += 1
diffs = ["Baixa", "Média", "Alta", "Muito alta"]
head(wr, r, ["Categoria"] + diffs + ["Total", "Esforço (d-p)", "Início", "Fim"]); r += 1
for cat in sorted({t[1] for t in ALL}):
    wr.cell(r, 1, cat).border = B
    for j, dfc in enumerate(diffs, 2):
        c = wr.cell(r, j, f'=COUNTIFS({rngc("Categoria")},$A{r},{rngc("Dificuldade")},"{dfc}")'); c.border = B; c.fill = PatternFill("solid", fgColor=DIFF[dfc])
    wr.cell(r, 6, f"=SUM(B{r}:E{r})").border = B
    wr.cell(r, 7, f'=SUMIFS({rngc("Esforço (dias-pessoa)")},{rngc("Categoria")},$A{r})').border = B
    c = wr.cell(r, 8, f'=_xlfn.MINIFS({rngc("Início")},{rngc("Categoria")},$A{r})'); c.number_format = "dd/mm/yyyy"; c.border = B
    c = wr.cell(r, 9, f'=_xlfn.MAXIFS({rngc("Fim")},{rngc("Categoria")},$A{r})'); c.number_format = "dd/mm/yyyy"; c.border = B
    r += 1
r += 1
wr.cell(r, 1, "Marcos").font = Font(bold=True, size=12, color=GREEN); r += 1
for t in ALL:
    if t[7] == 0:
        wr.cell(r, 1, human(t)[2]); c = wr.cell(r, 2, sched[t[0]][0]); c.number_format = "dd/mm/yyyy"; r += 1
for lbl, ids in [("Laboratório HAT pronto", ["G06"]), ("Piloto técnico do A2 no laboratório", ["H06", "H07"]),
                 ("Pacote final entregue à Vale", ["I08"]), ("Ambiente Vale (dev) validado", ["K12"])]:
    wr.cell(r, 1, lbl); c = wr.cell(r, 2, max(sched[i][1] for i in ids)); c.number_format = "dd/mm/yyyy"; r += 1
r += 1
wr.cell(r, 1, "Como ler a dificuldade").font = Font(bold=True, size=12, color=GREEN); r += 1
for dfc, desc in [("Baixa", "Tarefa de rotina, com passo a passo conhecido. Menos de um dia."),
                  ("Média", "Pede alguma decisão ou depende de outra área. Um a dois dias."),
                  ("Alta", "Envolve vários serviços, rede privada ou permissões. Precisa de especialista e pode exigir retrabalho."),
                  ("Muito alta", "Algo novo (ou em preview), com muitas dependências ou ordem crítica de passos.")]:
    wr.cell(r, 1, dfc).fill = PatternFill("solid", fgColor=DIFF[dfc]); wr.cell(r, 2, desc); r += 1
r += 1
wr.cell(r, 1, "Premissas").font = Font(bold=True, size=12, color=GREEN); r += 1
for p in ["Time HAT: 1 arquiteto cloud, 1 eng. cloud/DevOps, 1 eng. dados/IA (100%) + GP (30%).",
          "Os prazos da Vale são estimativas; dependem do calendário de mudanças e do congelamento de fim de ano.",
          "O laboratório HAT não usa nenhum dado da Vale (só dados de exemplo).",
          "Este cronograma cobre ambiente e habilitação; a construção funcional dos agentes A1–A4 segue o backlog da 1ª onda.",
          "Datas em dias úteis, com feriados nacionais e recesso de 24 e 31/12.",
          "Gantt: verde-claro = entrega inteira; verde = tarefa HAT/conjunta; azul = espera ou execução da Vale; dourado = marco."]:
    wr.cell(r, 1, "• " + p); r += 1
wr.column_dimensions["A"].width = 52
for col in "BCDEFGHI": wr.column_dimensions[col].width = 13
wr.column_dimensions["B"].width = 16

# ---------- Riscos ----------
wk_ = wb.create_sheet("Riscos")
riscos = [("R01", "O modelo de IA que queremos não estar disponível no Brasil, ou faltar capacidade", "Média", "Alto", "Checar no primeiro dia, pedir cota cedo e ter modelos alternativos; decisão formal com a Vale se for preciso usar outra região", "B06, SOL-GOV-05"),
("R02", "Serviços ainda em preview (controlador de fluxos, rede do serviço de agentes) mudarem", "Média", "Médio", "Versões parametrizadas no código, teste mensal e plano B (Durable Functions / Service Bus)", "F05, E04"),
("R03", "Regras da Vale bloquearem algum recurso (IP público, tamanhos, preview)", "Alta", "Alto", "Simular o deploy com a Vale cedo e pedir exceção formal", "SOL-GOV-04, K03"),
("R04", "Demora das áreas da Vale (firewall, DNS, identidade)", "Alta", "Alto", "Enviar os pedidos na semana 1, ter um ponto focal por área e fazer a sessão técnica", "J00, K01"),
("R05", "Congelamento de mudanças no fim do ano", "Alta", "Médio", "Abrir os pedidos de rede antes do freeze e usar o período para o piloto no laboratório", "A05"),
("R06", "Segurança da Vale não aprovar a porta pública do bot", "Média", "Alto", "Usar o firewall corporativo da Vale, ou começar o A1 por uma interface web interna", "SOL-NET-06"),
("R07", "Atraso na autorização para usar os dados com IA", "Média", "Alto", "Começar esse pedido na semana 1, mascarar dados sensíveis e usar amostra autorizada", "SOL-DAT-06"),
("R08", "Custo do laboratório passar do orçamento", "Baixa", "Baixo", "Alertas de orçamento, desligar à noite e recriar entre sprints", "B02"),
("R09", "Leitura do código (iFlows/Groovy) não ficar boa o suficiente", "Média", "Alto", "Dados de exemplo representativos e medição de qualidade na rotina de avaliação", "H02, E06")]
head(wk_, 1, ["ID", "Risco", "Probabilidade", "Impacto", "Como vamos reduzir", "Tarefas relacionadas", "Dono", "Status"])
for k, rk in enumerate(riscos, 2):
    for i, v in enumerate(list(rk) + ["GP HAT", "Aberto"], 1):
        c = wk_.cell(k, i, v); c.border = B; c.alignment = Alignment(wrap_text=True, vertical="top")
for i, wd in enumerate([6, 50, 13, 10, 60, 22, 12, 10], 1): wk_.column_dimensions[L(i)].width = wd

wb.save(f"{OUT}/cronograma/Cronograma_HAT_Vale_CDI.xlsx")
print("ok", len(ALL), "tarefas,", len(ENTREGAS), "entregas, fim", proj_end)
