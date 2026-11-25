import sys, datetime as dt
sys.path.insert(0, sys.argv[1]); OUT = sys.argv[2]
from tasks import T, T2, T3, SOL_DIFF, SOL_PRED
from solicitacoes import SOL
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.formatting.rule import FormulaRule, CellIsRule
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.utils import get_column_letter

START = dt.date(2026,11,30)
HOL = [dt.date(2026,12,24),dt.date(2026,12,25),dt.date(2026,12,31),dt.date(2027,1,1),
       dt.date(2027,2,8),dt.date(2027,2,9),dt.date(2027,3,26),dt.date(2027,4,21)]
HOLN = ["Véspera de Natal (recesso)","Natal","Véspera de Ano-Novo (recesso)","Confraternização Universal","Carnaval","Carnaval","Sexta-feira Santa","Tiradentes"]
def isw(d): return d.weekday()<5 and d not in HOL
def nextw(d):
    d += dt.timedelta(1)
    while not isw(d): d += dt.timedelta(1)
    return d
def firstw(d):
    while not isw(d): d += dt.timedelta(1)
    return d
def addw(d, n):  # end date for duration n (n>=1) starting at d
    k=1
    while k<n: d=nextw(d); k+=1
    return d

# assemble all tasks
sol_tasks=[]
for s in SOL:
    preds = ["J00"] + SOL_PRED.get(s[0], [])
    if s[0] in ("SOL-SEG-04","SOL-OPS-02","SOL-SEG-01"): preds = SOL_PRED[s[0]]
    sol_tasks.append((s[0],"J. Solicitações Vale",s[2],f"{s[3]} — Pronto quando: {s[7]}".replace("**","").replace("`",""),f"Vale — {s[5]}",SOL_DIFF[s[0]],0.5,s[6],preds))
ALL = T + T2 + sol_tasks + T3
byid = {t[0]:t for t in ALL}
sched = {}
def sch(i):
    if i in sched: return sched[i]
    t = byid[i]; preds=t[8]
    if not preds: s = firstw(START)
    else:
        mx = max(sch(p)[1] for p in preds)
        s = mx if t[7]==0 else nextw(mx)
    e = s if t[7]==0 else addw(s, t[7])
    sched[i]=(s,e); return s,e
for t in ALL: sch(t[0])
proj_end = max(e for s,e in sched.values())

# order: by category letter, keep list order inside
catorder = sorted({t[1] for t in ALL})
rows = []
for c in catorder:
    rows += [t for t in ALL if t[1]==c]

# ---------- workbook ----------
wb = Workbook()
GREEN="0B3D2E"; LG="E8F1EC"
thin = Side(style='thin', color='C8D3CD'); B = Border(left=thin,right=thin,top=thin,bottom=thin)
H = Font(bold=True, color="FFFFFF"); HF = PatternFill("solid", fgColor=GREEN)
DIFF_FILL = {"Baixa":"D4EDDA","Média":"FFF3CD","Alta":"F8D7DA","Muito alta":"E3B7EB"}

# ----- Feriados -----
wf = wb.active; wf.title="Feriados"
wf.append(["Data","Descrição"])
for d,n in zip(HOL,HOLN): wf.append([d,n])
for c in wf[1]: c.font=H; c.fill=HF
for r in wf.iter_rows(min_row=2, max_col=1):
    for c in r: c.number_format="dd/mm/yyyy"
wf.column_dimensions['A'].width=14; wf.column_dimensions['B'].width=34

# ----- Cronograma -----
ws = wb.create_sheet("Cronograma", 0)
ws["A1"] = "Cronograma — Ambiente HAT, pacote Vale e implantação Core Data Integration"; ws["A1"].font=Font(bold=True,size=14,color=GREEN)
ws["A2"] = f"Início: {START:%d/%m/%Y} · Término previsto: {proj_end:%d/%m/%Y} · Dias úteis (feriados na aba Feriados). Fim = DIATRABALHO(Início; Duração−1; Feriados). Edite Início/Duração e o Gantt se ajusta."
ws["A2"].font=Font(italic=True,size=9)
hdr = ["ID","Categoria","Tarefa","Descrição / entregável","Responsável","Dificuldade","Esforço (dias-pessoa)","Duração (dias úteis)","Predecessoras","Início","Fim","Status","Mês do projeto"]
HR=4
for i,h in enumerate(hdr,1):
    c=ws.cell(HR,i,h); c.font=H; c.fill=HF; c.alignment=Alignment(wrap_text=True,vertical='center',horizontal='center'); c.border=B
# weeks
weeks=[]; w=START - dt.timedelta(START.weekday())
while w<=proj_end: weeks.append(w); w+=dt.timedelta(7)
G0 = len(hdr)+1
for j,wk in enumerate(weeks):
    c=ws.cell(HR,G0+j,wk); c.number_format="dd/mm"; c.font=Font(bold=True,color="FFFFFF",size=8); c.fill=HF
    c.alignment=Alignment(text_rotation=90,horizontal='center'); ws.column_dimensions[get_column_letter(G0+j)].width=3.2
    m=ws.cell(HR-1,G0+j, f"S{j+1}"); m.font=Font(size=7,color="666666"); m.alignment=Alignment(horizontal='center')
r=HR+1; first=r
def mes(d):
    n=(d-START).days//30+1
    return f"Mês {min(n,6)}"
for t in rows:
    s,e = sched[t[0]]
    vals=[t[0],t[1],t[2],t[3],t[4],t[5],t[6],t[7],", ".join(t[8]),s,None,"Não iniciado",mes(s)]
    for i,v in enumerate(vals,1):
        c=ws.cell(r,i,v); c.border=B; c.alignment=Alignment(wrap_text=(i in (3,4,9)),vertical='top')
    ws.cell(r,10).number_format="dd/mm/yyyy"
    ws.cell(r,11,f'=IF(H{r}=0,J{r},WORKDAY(J{r},H{r}-1,Feriados!$A$2:$A$50))').number_format="dd/mm/yyyy"
    ws.cell(r,11).border=B
    ws.cell(r,6).fill=PatternFill("solid",fgColor=DIFF_FILL[t[5]])
    if t[7]==0:
        for i in range(1,len(hdr)+1): ws.cell(r,i).font=Font(bold=True,color=GREEN)
    r+=1
last=r-1
widths=[9,26,40,60,24,11,10,10,18,11,11,13,9]
for i,wd in enumerate(widths,1): ws.column_dimensions[get_column_letter(i)].width=wd
ws.freeze_panes=ws.cell(HR+1,4)
ws.auto_filter.ref=f"A{HR}:{get_column_letter(len(hdr))}{last}"
# Gantt CF
gl=get_column_letter(G0); gr=get_column_letter(G0+len(weeks)-1)
rng=f"{gl}{first}:{gr}{last}"
ws.conditional_formatting.add(rng, FormulaRule(formula=[f'AND($H{first}=0,$J{first}>={gl}${HR},$J{first}<={gl}${HR}+6)'], fill=PatternFill("solid",fgColor="C9A227")))
ws.conditional_formatting.add(rng, FormulaRule(formula=[f'AND(LEFT($E{first},4)="Vale",$J{first}<={gl}${HR}+6,$K{first}>={gl}${HR})'], fill=PatternFill("solid",fgColor="9BB7D4")))
ws.conditional_formatting.add(rng, FormulaRule(formula=[f'AND($J{first}<={gl}${HR}+6,$K{first}>={gl}${HR})'], fill=PatternFill("solid",fgColor="2E8B57")))
for rr in range(first,last+1):
    for j in range(len(weeks)): ws.cell(rr,G0+j).border=B
dv=DataValidation(type="list", formula1='"Não iniciado,Em andamento,Bloqueado,Concluído,Cancelado"', allow_blank=True)
ws.add_data_validation(dv); dv.add(f"L{first}:L{last}")
ws.conditional_formatting.add(f"L{first}:L{last}", CellIsRule(operator='equal', formula=['"Concluído"'], fill=PatternFill("solid",fgColor="D4EDDA")))
ws.conditional_formatting.add(f"L{first}:L{last}", CellIsRule(operator='equal', formula=['"Bloqueado"'], fill=PatternFill("solid",fgColor="F8D7DA")))
ws.conditional_formatting.add(f"L{first}:L{last}", CellIsRule(operator='equal', formula=['"Em andamento"'], fill=PatternFill("solid",fgColor="FFF3CD")))

# ----- Solicitações Vale -----
wv = wb.create_sheet("Solicitações Vale",1)
hv=["ID","Categoria","Solicitação","O que solicitamos","Justificativa (arquitetura)","Responsável Vale","Prioridade","Dificuldade","Lead time (d.u.)","Bloqueia","Critério de pronto","Data envio","Previsão (envio + lead time)","Status","Nº chamado Vale","Observações"]
for i,h in enumerate(hv,1):
    c=wv.cell(1,i,h); c.font=H; c.fill=HF; c.alignment=Alignment(wrap_text=True,vertical='center'); c.border=B
for k,s in enumerate(SOL, start=2):
    st,_=sched[s[0]]
    vals=[s[0],s[1],s[2],s[3].replace("**","").replace("`",""),s[4],s[5],s[9],SOL_DIFF[s[0]],s[6],s[8],s[7],st,None,"A enviar","",""]
    for i,v in enumerate(vals,1):
        c=wv.cell(k,i,v); c.border=B; c.alignment=Alignment(wrap_text=True,vertical='top')
    wv.cell(k,12).number_format="dd/mm/yyyy"
    wv.cell(k,13,f'=WORKDAY(L{k},I{k},Feriados!$A$2:$A$50)').number_format="dd/mm/yyyy"
    wv.cell(k,8).fill=PatternFill("solid",fgColor=DIFF_FILL[SOL_DIFF[s[0]]])
    if s[9]=="Crítica": wv.cell(k,7).fill=PatternFill("solid",fgColor="F8D7DA")
    elif s[9]=="Alta": wv.cell(k,7).fill=PatternFill("solid",fgColor="FFF3CD")
lv=len(SOL)+1
for i,wd in enumerate([11,14,34,60,44,24,10,11,9,18,34,11,12,13,14,24],1): wv.column_dimensions[get_column_letter(i)].width=wd
dv2=DataValidation(type="list", formula1='"A enviar,Enviado,Em análise,Aprovado,Implementado,Validado (HAT),Recusado"', allow_blank=True)
wv.add_data_validation(dv2); dv2.add(f"N2:N{lv}")
wv.freeze_panes="D2"; wv.auto_filter.ref=f"A1:P{lv}"

# ----- Resumo -----
wr = wb.create_sheet("Resumo",0)
wr["A1"]="Core Data Integration — Ambiente Azure HAT ⇄ Vale"; wr["A1"].font=Font(bold=True,size=16,color=GREEN)
wr["A2"]="Roteiro, pacote de solicitações e implantação — cronograma de referência"; wr["A2"].font=Font(italic=True)
info=[("Início",START),("Término previsto",proj_end),("Total de tarefas",len(ALL)),("Solicitações à Vale",len(SOL)),
      ("Esforço HAT estimado (dias-pessoa)", f"=SUMIFS(Cronograma!G:G,Cronograma!E:E,\"<>Vale*\")")]
r=4
for k,v in info:
    wr.cell(r,1,k).font=Font(bold=True); c=wr.cell(r,2,v)
    if isinstance(v,dt.date): c.number_format="dd/mm/yyyy"
    r+=1
r+=1
wr.cell(r,1,"Tarefas por categoria e dificuldade").font=Font(bold=True,size=12,color=GREEN); r+=1
diffs=["Baixa","Média","Alta","Muito alta"]
hdrs=["Categoria"]+diffs+["Total","Esforço (d-p)","Início","Fim"]
for i,h in enumerate(hdrs,1):
    c=wr.cell(r,i,h); c.font=H; c.fill=HF; c.border=B
r+=1
for cat in catorder:
    wr.cell(r,1,cat).border=B
    for j,dfc in enumerate(diffs,2):
        c=wr.cell(r,j,f'=COUNTIFS(Cronograma!$B:$B,$A{r},Cronograma!$F:$F,"{dfc}")'); c.border=B; c.fill=PatternFill("solid",fgColor=DIFF_FILL[dfc])
    wr.cell(r,6,f'=SUM(B{r}:E{r})').border=B
    wr.cell(r,7,f'=SUMIFS(Cronograma!$G:$G,Cronograma!$B:$B,$A{r})').border=B
    c=wr.cell(r,8,f'=_xlfn.MINIFS(Cronograma!$J:$J,Cronograma!$B:$B,$A{r})'); c.number_format="dd/mm/yyyy"; c.border=B
    c=wr.cell(r,9,f'=_xlfn.MAXIFS(Cronograma!$K:$K,Cronograma!$B:$B,$A{r})'); c.number_format="dd/mm/yyyy"; c.border=B
    r+=1
r+=1
wr.cell(r,1,"Marcos").font=Font(bold=True,size=12,color=GREEN); r+=1
for t in ALL:
    if t[7]==0:
        wr.cell(r,1,t[2]); c=wr.cell(r,2,sched[t[0]][0]); c.number_format="dd/mm/yyyy"; r+=1
for lbl,ids in [("Ambiente HAT pronto (F0–F5)",["G06"]),("Prova técnica no lab (F6)",["H06","H07"]),("Pacote final enviado à Vale",["I08"]),("Ambiente Vale dev validado",["K12"])]:
    wr.cell(r,1,lbl); c=wr.cell(r,2,max(sched[i][1] for i in ids)); c.number_format="dd/mm/yyyy"; r+=1
r+=1
wr.cell(r,1,"Escala de dificuldade").font=Font(bold=True,size=12,color=GREEN); r+=1
for dfc,desc in [("Baixa","Rotina, padrão documentado, < 1 dia, risco baixo"),("Média","Configuração com decisões ou dependência de outra área; 1–2 dias"),("Alta","Integração entre vários serviços/rede privada/RBAC; requer especialista; risco de retrabalho"),("Muito alta","Componente novo/preview, várias dependências, ordem crítica ou código de produto (ingestão/MCP)")]:
    wr.cell(r,1,dfc).fill=PatternFill("solid",fgColor=DIFF_FILL[dfc]); wr.cell(r,2,desc); r+=1
r+=1
wr.cell(r,1,"Premissas").font=Font(bold=True,size=12,color=GREEN); r+=1
for p in ["Time HAT: 1 arquiteto cloud, 1 eng. cloud/DevOps, 1 eng. dados/IA (100%) + GP (30%).",
          "Lead times da Vale são estimativas; prazo real depende do calendário de mudanças (SOL-OPS-01) e do freeze de fim de ano.",
          "Ambiente HAT não usa dados da Vale (corpus sintético).",
          "Cronograma cobre ambiente/infra e habilitação; desenvolvimento funcional dos agentes A1–A4 (Mês 3) segue o backlog da 1ª onda.",
          "Datas calculadas em dias úteis, com feriados nacionais e recessos de 24 e 31/12.",
          "Legenda do Gantt: verde = tarefa HAT/conjunta; azul = espera/execução Vale; dourado = marco."]:
    wr.cell(r,1,"• "+p); r+=1
wr.column_dimensions['A'].width=46
for col in "BCDEFGHI": wr.column_dimensions[col].width=13

# ----- Riscos -----
wk = wb.create_sheet("Riscos")
riscos=[("R01","Modelo indisponível em Brazil South Standard regional ou sem cota","Média","Alto","Preflight no dia 1; pedido de cota; modelos alternativos; decisão formal se precisar Global","B06, SOL-GOV-05"),
("R02","APIs em preview (Durable Task Scheduler, network injection do Agent Service) mudarem","Média","Médio","api-version parametrizável; teste mensal; fallback Durable Functions/Service Bus","F05, E04"),
("R03","Policies da Vale bloquearem recursos (IP público, SKUs, preview)","Alta","Alto","What-if com a Vale cedo; exemption formal","SOL-GOV-04, K03"),
("R04","Lead time de firewall/DNS/IAM na Vale","Alta","Alto","Envio do pacote na semana 1; ponto focal por área; sessão técnica","J00, K01"),
("R05","Freeze de mudanças de fim de ano","Alta","Médio","CRs de rede antes do freeze; usar o período para a prova técnica no lab","A05"),
("R06","Entrada pública do Bot recusada pela Segurança","Média","Alto","Alternativa via WAF/Front Door corporativo; piloto inicial do A1 por interface web interna","SOL-NET-06"),
("R07","Autorização de uso de dados em LLM atrasar","Média","Alto","Iniciar SOL-DAT-06 na semana 1; mascaramento no gateway; amostra autorizada","SOL-DAT-06"),
("R08","Custo do lab acima do budget","Baixa","Baixo","Budget/alertas; start-stop-lab.sh; destruir/recriar entre sprints","B02"),
("R09","Qualidade da ingestão (parser .iflw/Groovy) abaixo do esperado","Média","Alto","Corpus sintético representativo; métricas de recall no job-avaliacao","H02, E06"),
]
hk=["ID","Risco","Probabilidade","Impacto","Mitigação","Tarefas relacionadas","Dono","Status"]
for i,h in enumerate(hk,1):
    c=wk.cell(1,i,h); c.font=H; c.fill=HF; c.border=B
for k,rk in enumerate(riscos,2):
    for i,v in enumerate(rk,1):
        c=wk.cell(k,i,v); c.border=B; c.alignment=Alignment(wrap_text=True,vertical='top')
    wk.cell(k,7,"GP HAT").border=B; wk.cell(k,8,"Aberto").border=B
for i,wd in enumerate([6,50,13,10,60,22,12,10],1): wk.column_dimensions[get_column_letter(i)].width=wd

wb.save(f"{OUT}/cronograma/Cronograma_HAT_Vale_CDI.xlsx")
# print schedule summary for the md
import json
json.dump({k:[v[0].isoformat(),v[1].isoformat()] for k,v in sched.items()}, open(f"{sys.argv[1]}/sched.json","w"))
print("fim", proj_end, "tarefas", len(ALL))
for i in ["A01","B08","C04","D10","E07","F08","G06","H06","H07","I03","J00","I08","K03","K07","K12","L01","L02","L03","L04"]:
    print(i, sched[i][0], sched[i][1])
