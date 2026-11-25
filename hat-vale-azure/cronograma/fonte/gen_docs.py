import sys
sys.path.insert(0, sys.argv[1])
from solicitacoes import SOL, ANEXO_A, ANEXO_B
OUT = sys.argv[2]
from collections import OrderedDict

cats = OrderedDict()
for s in SOL: cats.setdefault(s[1], []).append(s)

md = []
md.append("# 03 · Solicitações de acesso e permissões — Vale\n")
md.append("> Pacote de solicitações para habilitar o ambiente **Core Data Integration** na Vale (`rg-integia-dev-brs`). Cada item foi exercitado no ambiente HAT (lab) com o mesmo IaC — o que pedimos é exatamente o que o código precisa. Versão formal para envio: `Solicitacoes_Acessos_Vale_CDI.docx`.\n")
md.append("**Como usar:** (1) enviar o pacote na semana 1 junto com o plano do assessment (slide 34, passo 04 — *Vale disponibiliza documentos, código, ambientes e acessos*); (2) abrir um chamado por linha (ou por grupo de responsável) usando o ID `SOL-*` como referência; (3) acompanhar o status no cronograma (`cronograma/Cronograma_HAT_Vale_CDI.xlsx`, aba *Solicitações Vale*).\n")
md.append("**Lead time** = estimativa em dias úteis a partir da abertura, com base em padrões de grandes empresas; ajustar com o calendário de mudanças da Vale (SOL-OPS-01).\n")
md.append("## Resumo\n")
md.append("| ID | Solicitação | Responsável Vale | Lead time (d.u.) | Prioridade | Bloqueia |")
md.append("|---|---|---|---|---|---|")
for s in SOL:
    md.append(f"| {s[0]} | {s[2]} | {s[5]} | {s[6]} | {s[9]} | {s[8]} |")
md.append("")
for c, items in cats.items():
    md.append(f"## {c}\n")
    for s in items:
        md.append(f"### {s[0]} — {s[2]}\n")
        md.append(f"- **O que solicitamos:** {s[3]}")
        md.append(f"- **Por quê (referência na arquitetura):** {s[4]}")
        md.append(f"- **Responsável Vale:** {s[5]} · **Lead time:** {s[6]} d.u. · **Prioridade:** {s[9]} · **Bloqueia:** {s[8]}")
        md.append(f"- **Critério de pronto:** {s[7]}\n")
md.append("## Anexo A — Allow-list de saída (Firewall/NVA do hub)\n")
md.append("| Destino | Porta | Origem | Finalidade |")
md.append("|---|---|---|---|")
for a in ANEXO_A: md.append(f"| {a[0]} | {a[1]} | {a[2]} | {a[3]} |")
md.append("\nObservação: tráfego para os PaaS do projeto (Storage, Search, Cosmos, Foundry, KV, ACR, Service Bus) **não** passa pelo firewall — vai por Private Endpoint dentro da spoke. Valores `<...>` são confirmados com o time BTP/LeanIX (SOL-NET-07).\n")
md.append("## Anexo B — Zonas DNS privadas necessárias\n")
for z in ANEXO_B: md.append(f"- `{z}`")
md.append("\n## Anexo C — Modelo de e-mail de encaminhamento\n")
md.append("""```text
Assunto: [Core Data Integration] Solicitações de ambiente e acessos — 1ª onda (ref. SOL-*)

Prezados,

Conforme o plano de mobilização do projeto Core Data Integration (Integração / Strategy Lab),
encaminhamos o pacote de solicitações necessárias para implantar o ambiente rg-integia-dev-brs
em Brazil South, com acesso exclusivamente privado (Private Endpoints) e identidades gerenciadas.

O desenho e o código de infraestrutura (Bicep) já foram validados em ambiente espelho da HAT
Thinking; anexamos o relatório de validação, a matriz de identidades/RBAC e o what-if.

Itens críticos para o Mês 1 (Assessment) e início do Mês 2 (Foundation):
  SOL-GOV-01/02, SOL-NET-01/02/03/04, SOL-IAM-01/03/04, SOL-DAT-01/02/03/06, SOL-DEV-02, SOL-SEG-01.

Pedimos a indicação de um ponto focal por área responsável e a confirmação dos prazos.
Ficamos à disposição para uma sessão técnica de 1h com Rede/DNS, IAM e Cloud CoE.

Atenciosamente,
HAT Thinking — Equipe Core Data Integration
```
""")
md.append("## Anexo D — Controle de status\n")
md.append("Status possíveis: `A enviar` → `Enviado` → `Em análise` → `Aprovado` → `Implementado` → `Validado (HAT)`. O status vive na aba *Solicitações Vale* do cronograma.\n")
open(f"{OUT}/docs/03-solicitacoes-permissoes-vale.md","w").write("\n".join(md))

# ---------- DOCX ----------
from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

def shade(cell, hexcolor):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd'); shd.set(qn('w:val'),'clear'); shd.set(qn('w:color'),'auto'); shd.set(qn('w:fill'),hexcolor)
    tcPr.append(shd)

d = Document()
for s in d.sections:
    s.left_margin = s.right_margin = Cm(2); s.top_margin = s.bottom_margin = Cm(2)
st = d.styles['Normal']; st.font.name = 'Calibri'; st.font.size = Pt(10)

t = d.add_paragraph(); r = t.add_run("Core Data Integration — Vale"); r.bold=True; r.font.size=Pt(20); r.font.color.rgb=RGBColor(0x0B,0x3D,0x2E)
t = d.add_paragraph(); r = t.add_run("Solicitação de ambiente, acessos e permissões — 1ª onda"); r.font.size=Pt(14)
d.add_paragraph("Emissor: HAT Thinking · Destinatários: Cloud CoE, Rede/DNS, Segurança da Informação, IAM, M365/Teams, Azure DevOps, BTP, Arquitetura Corporativa, ITSM — Vale")
d.add_paragraph("Ambiente alvo: rg-integia-dev-brs · Região: Brazil South (região única de dados) · Acesso: somente Private Endpoint")

d.add_heading("1. Contexto", level=1)
d.add_paragraph("A área de Integração está estruturando a Core Data Foundation que habilita os agentes A1 (Integration Business Analyst), A2 (Integration Engineer), A3 (Integration Support Engineer) e A4 (Integration Knowledge Engineer), com validação humana (CCI, arquitetos e especialistas) antes de qualquer alteração em documentos, código ou cadastro. A arquitetura usa Microsoft Foundry, Azure AI Search, ADLS Gen2, PostgreSQL Flexible (registro e grafo Apache AGE), API Management interno e Container Apps em VNet spoke, sem acesso público aos serviços PaaS.")
d.add_paragraph("A infraestrutura foi implementada como código (Bicep) e validada em ambiente espelho da HAT. Este documento lista o que é necessário do lado Vale para implantar o mesmo código, com justificativa, responsável sugerido, prazo estimado e critério de pronto.")

d.add_heading("2. Resumo das solicitações", level=1)
tb = d.add_table(rows=1, cols=6); tb.style = 'Table Grid'
hdr = ["ID","Solicitação","Responsável","Lead time (d.u.)","Prioridade","Bloqueia"]
for i,h in enumerate(hdr):
    c = tb.rows[0].cells[i]; c.text = h; c.paragraphs[0].runs[0].bold=True; shade(c,'0B3D2E'); c.paragraphs[0].runs[0].font.color.rgb=RGBColor(255,255,255)
for s in SOL:
    row = tb.add_row().cells
    vals = [s[0], s[2], s[5], str(s[6]), s[9], s[8]]
    for i,v in enumerate(vals):
        row[i].text = v
        for p in row[i].paragraphs:
            for rr in p.runs: rr.font.size = Pt(8.5)
    if s[9]=="Crítica": shade(row[4],'F8D7DA')
    elif s[9]=="Alta": shade(row[4],'FFF3CD')

d.add_heading("3. Detalhamento", level=1)
for c, items in cats.items():
    d.add_heading(c, level=2)
    for s in items:
        d.add_heading(f"{s[0]} — {s[2]}", level=3)
        tb = d.add_table(rows=0, cols=2); tb.style='Table Grid'
        for k,v in [("O que solicitamos",s[3]),("Justificativa",s[4]),("Responsável Vale",s[5]),("Lead time estimado",f"{s[6]} dias úteis"),("Prioridade",s[9]),("Bloqueia",s[8]),("Critério de pronto",s[7]),("Status / data","")]:
            r = tb.add_row().cells; r[0].text=k; r[1].text=v.replace("**","").replace("`","")
            r[0].paragraphs[0].runs[0].bold=True; shade(r[0],'E8F1EC'); r[0].width=Cm(4); r[1].width=Cm(13)
        d.add_paragraph()

d.add_heading("Anexo A — Allow-list de saída (Firewall/NVA)", level=1)
tb = d.add_table(rows=1, cols=4); tb.style='Table Grid'
for i,h in enumerate(["Destino","Porta","Origem","Finalidade"]):
    tb.rows[0].cells[i].text=h; tb.rows[0].cells[i].paragraphs[0].runs[0].bold=True; shade(tb.rows[0].cells[i],'E8F1EC')
for a in ANEXO_A:
    r = tb.add_row().cells
    for i,v in enumerate(a):
        r[i].text=v
        for rr in r[i].paragraphs[0].runs: rr.font.size=Pt(8.5)
d.add_paragraph("Tráfego para os PaaS do projeto não passa pelo firewall: é feito por Private Endpoint dentro da spoke.")
d.add_heading("Anexo B — Zonas DNS privadas", level=1)
for z in ANEXO_B: d.add_paragraph(z, style='List Bullet')
d.add_heading("Anexo C — Documentos de apoio", level=1)
for x in ["Roteiro do ambiente e arquitetura (docs/01)","Guia de criação dos recursos (docs/02)","Matriz de identidades e RBAC (docs/04)","Código IaC Bicep e scripts (iac/)","Relatório de validação do ambiente espelho HAT (04-validate.sh)","Cronograma detalhado (Cronograma_HAT_Vale_CDI.xlsx)"]:
    d.add_paragraph(x, style='List Bullet')
d.add_heading("Aprovações", level=1)
tb = d.add_table(rows=1, cols=4); tb.style='Table Grid'
for i,h in enumerate(["Área","Nome","Decisão","Data"]):
    tb.rows[0].cells[i].text=h; shade(tb.rows[0].cells[i],'E8F1EC')
for a in ["Cloud CoE","Rede / DNS","Segurança da Informação","IAM","Integração (gestão)","HAT Thinking"]:
    r = tb.add_row().cells; r[0].text=a
d.save(f"{OUT}/docs/Solicitacoes_Acessos_Vale_CDI.docx")
print("ok", len(SOL))
