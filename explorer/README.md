# Raio-X dos System Prompts

Sistema visual e interativo para estudar system prompts de IAs, a partir do acervo
[asgeirtj/system_prompts_leaks](https://github.com/asgeirtj/system_prompts_leaks) e dos prompts deste repositório.

Abra `explorer/index.html` no navegador. Não precisa de servidor nem de instalação.

## O que tem

| Vista | Para que serve |
|---|---|
| **Início** | Números do acervo, trechos reais sendo “revelados” e mapa de bolhas por empresa |
| **Anatomia** | As 10 camadas de um system prompt montadas passo a passo, com exemplos reais, o fluxo de uma mensagem e a proporção de cada camada por empresa |
| **Explorar** | Busca e filtros (empresa, tipo, técnica, fonte) em 1.845 arquivos. O detalhe traz métricas, radar de técnicas, diagnóstico com pontos fortes e melhorias, estrutura, e o texto completo destacado por técnica |
| **Linha do tempo** | Corrida animada de prompts acumulados por empresa, histograma mensal e evolução de tamanho dentro de uma família de modelos |
| **Comparar** | Dois prompts lado a lado: radar sobreposto, tabela de métricas e títulos exclusivos ou em comum |
| **Técnicas** | 12 padrões detectados, com explicação, faça/evite, exemplos reais de várias empresas e prompts para estudar |
| **Laboratório** | Analisa o seu prompt localmente (nota de cobertura, radar, sugestões) e gera um prompt estruturado a partir de um formulário |
| **Trilha** | 8 etapas de aprendizado com leituras e exercícios, progresso salvo no navegador |
| **Como usar** | Guia, leitura das métricas, lições práticas e segurança |

## Atualizar os dados

```bash
git clone --depth 1 https://github.com/asgeirtj/system_prompts_leaks.git /tmp/spl
git clone --filter=blob:none --no-checkout https://github.com/asgeirtj/system_prompts_leaks.git /tmp/spl-hist
python3 explorer/build.py \
  --source asgeirtj=/tmp/spl --history asgeirtj=/tmp/spl-hist \
  --repo-url asgeirtj=asgeirtj/system_prompts_leaks@main \
  --source local=. --repo-url local=hudsonrj/leaked-system-prompts@main
```

`build.py` gera `data/catalog.js` com metadados, métricas, técnicas detectadas e exemplos.
O texto completo de cada prompt é buscado do GitHub sob demanda.

## Como as métricas são calculadas

- **Tokens**: caracteres ÷ 4 (estimativa).
- **Técnicas**: contagem de padrões de texto (regex) por técnica; **densidade** = ocorrências por 10 mil caracteres.
- **Radar**: densidade normalizada pelo percentil 95 dos prompts em destaque.
- **Datas**: nome do arquivo ou commit que adicionou o arquivo ao repositório.

A detecção é heurística: mostra tendências, não substitui a leitura.
