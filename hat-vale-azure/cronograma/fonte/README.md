# Fonte do cronograma e das solicitações

- `tasks.py` — tarefas (categoria, dificuldade, esforço, duração, predecessoras)
- `solicitacoes.py` — catálogo único das 34 solicitações à Vale + anexos A/B
- `build_xlsx.py` — calcula datas (dias úteis + feriados) e gera `../Cronograma_HAT_Vale_CDI.xlsx`
- `gen_docs.py` — gera `docs/03-solicitacoes-permissoes-vale.md` e `docs/Solicitacoes_Acessos_Vale_CDI.docx`

```bash
pip install openpyxl python-docx
cd cronograma/fonte
python3 build_xlsx.py . ../..
python3 gen_docs.py . ../..
```
Altere a data de início em `build_xlsx.py` (`START`) para replanejar.
