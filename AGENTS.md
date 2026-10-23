# panorama-graph-skills — Guia para agentes

Este arquivo diz **como trabalhar** no repositório. **O que cada skill faz** está no [README.md](README.md).

## Regras

- **A skill segue o produto, e não o contrário.** A ingestão ensina o modelo pelos documentos do [panorama-graph](https://github.com/panorama-graph/panorama-graph) (`MODELO.md`, `ADAPTADOR.md`, `PROVENIENCIA.md`, `key-recipes.json`). A carga manual usa o formato dos schemas em `schemas/` do [panorama-graph-adapters](https://github.com/panorama-graph/panorama-graph-adapters) e as regras de tradução do `graph-publish`. Os dois conjuntos são baixados pelo `install.sh` na instalação, e nunca copiados para cá. Mudou o modelo, um formato, um tradutor, uma receita de chave ou a versão do plugin? Atualize as referências das skills e os exemplos em seguida (e, na carga manual, o init script).
- **Fontes e escopos dos adaptadores.** Na ingestão, os fatos de um componente lidos do código vão repartidos pelas fontes de build, como o `graph-publish` reparte (`build-manifest`, `openapi`, `asyncapi`, `http-clients`, `data-access`, `sbom`, `pact`). Mudou o que um tradutor afirma em cada fonte? Atualize a tabela de [retratos.md](skills/panorama-graph-ingestao/referencias/retratos.md#repartir-os-fatos-pelas-fontes) e o exemplo.
- **Descoberta nas duas skills.** Onde procurar cada fato no código está nas duas: em [descoberta.md da ingestão](skills/panorama-graph-ingestao/referencias/descoberta.md), em nós e relações; em [descoberta.md da carga manual](skills/panorama-graph-carga-manual/referencias/descoberta.md), nos campos dos artefatos. Instrução nova de descoberta entra nas duas.
- **Mesmas fontes e escopos dos adaptadores reais.** A carga gerada pela skill nunca usa fonte `manual`, `seed` ou `agente`: ela precisa ser substituída, sem limpeza, pelo primeiro envio do adaptador do mesmo assunto.
- **Fontes só de leitura.** Nenhuma instrução manda escrever, commitar ou instalar algo no projeto explorado, nem alterar um cluster, um catálogo ou um diretório. Cada acesso da ingestão tem a lista do que lê e do que nunca faz. A exceção é o `build/` do Gradle, ignorado pelo git, pelo init script da carga manual.
- **Exemplos neutros.** Nada da organização de exemplo (ACME Bank) nas skills: os exemplos usam `example.com` e uma loja fictícia.
- **O que não se descobre vira lacuna.** Instrução nova de descoberta diz onde procurar, o que extrair e o que fazer quando não resolve. Nunca diga ao agente para deduzir ou completar.

## Estrutura de uma skill

| Caminho | Papel |
|---|---|
| `SKILL.md` | Frontmatter (`name` igual à pasta, `description` do que faz e de quando usar) e o roteiro: regras, entradas, saída e fases |
| `referencias/` | O que o agente lê quando precisa. Na ingestão: o que pode ser importado (`o-que-importar.md`), onde procurar cada fato (`descoberta.md`) e como montar o retrato (`retratos.md`). Na carga manual: `descoberta.md`, os formatos (`formatos.md`), a organização e as chaves (`organizacao.md`) |
| `produto/` | Os documentos do modelo, baixados do panorama-graph pelo `install.sh` para as skills de `PRODUCT_SKILLS` (fora do git) |
| `schemas/` | Os schemas dos formatos de build, baixados pelo `install.sh` para as skills de `SCHEMA_SKILLS` (fora do git) |
| `modelos/` | Arquivos que o agente usa como estão (o init script do Gradle) |
| `scripts/` | O que o agente roda (`enviar.sh` na ingestão, `importar.sh` na carga manual) |
| `exemplos/` | Uma carga completa, neutra, que passa no dry-run |

## Testes

- `./install.sh --project <pasta temporária> --claude --agents`: cada cópia tem o `SKILL.md`, as referências, os documentos do modelo (ingestão) e os schemas dos adaptadores (carga manual). Sem rede, `--product-dir` com uma cópia local do panorama-graph e `--schemas-dir` com a pasta `schemas/` de uma cópia local dos adaptadores.
- `enviar.sh --dry-run` sobre o `exemplos/carga-grafo` da ingestão, contra uma API no ar (`docker compose up -d` no panorama-graph): sai `0`, sem `stale`. Uma carga e uma segunda carga, só com `=`, numa instância de teste. Contra uma API sem dry-run, o script recusa sem enviar nada.
- `importar.sh --dry-run` sobre `exemplos/carga-grafo` contra uma instância no ar (`docker compose up -d` no panorama-graph, para a API, e nos adaptadores, para o receptor): sai `0`, sem aviso.
- O init script num projeto Gradle sem o plugin, com e sem `-x test`, e o build do projeto sem nenhuma mudança fora de `build/`.
- Mudança nas instruções de descoberta: rode a skill num serviço que já publica pelo plugin, forçando a leitura do código, e compare com o `build/architecture` do plugin (o gabarito): o que acertou, o que perdeu e o que inventou.
