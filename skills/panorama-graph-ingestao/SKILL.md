---
name: panorama-graph-ingestao
description: Carrega no panorama-graph a arquitetura e a estrutura da organização pela ingestão nativa da API (POST /v1/ingest), a partir do que o agente consegue ler, sem modificar nada. As fontes são os repositórios de código, a configuração e os manifestos de implantação, e os acessos disponíveis, como CLIs (git, gh, glab, kubectl, helm, az, aws), MCPs, APIs de catálogo e de diretório e exports. Conhece o modelo do grafo e explica o que pode ser importado e de onde. Descobre cada fato com evidência, monta os retratos (fonte, escopo, nós e relações), confere por dry-run e envia só com confirmação. Use quando alguém quer alimentar o grafo sem um adaptador pronto, ou saber o que dá para importar das fontes que tem.
---

# Ingestão no panorama-graph

O grafo guarda fatos: nós (componente, API, time, banco) e relações entre eles. Cada fato é afirmado por uma **fonte**, num **escopo**, com **evidência**. Esta skill lê o que está ao seu alcance e monta os fatos no formato da API, um retrato por fonte e escopo. Depois envia os retratos ao `POST /v1/ingest`.

A skill depende só da API do produto. Não usa adaptador, plugin nem receptor.

Os retratos usam a mesma fonte e o mesmo escopo que o adaptador do assunto usaria. Assim, quando a organização adotar os adaptadores, o primeiro envio deles substitui esta carga sem limpeza.

**Não use para uma fonte que um adaptador já publica.** O `sources_status` mostra a fonte e o escopo com cargas recentes. Nesse caso, a carga manual brigaria com a real: avise a pessoa e deixe esse assunto de fora.

## O modelo

A skill traz, em [produto/](produto/), os documentos do panorama-graph na versão instalada. O `install.sh` os baixa do repositório do produto.

| Arquivo | O que tem | Quando ler |
|---|---|---|
| [produto/MODELO.md](produto/MODELO.md) | Os tipos de nó e de relação, os pares válidos, as propriedades, os valores fixos, as receitas de chave, as versões de APIs e tópicos, e o que fazer quando algo não cabe | Sempre, antes de montar o primeiro retrato |
| [produto/ADAPTADOR.md](produto/ADAPTADOR.md) | O retrato campo a campo, fonte e escopo, as respostas da API e um exemplo de carga para cada relação | Ao montar cada retrato, e em toda dúvida sobre uma relação |
| [produto/PROVENIENCIA.md](produto/PROVENIENCIA.md) | Como o grafo trata afirmações, `stale` e conflitos | Para explicar à pessoa o que a carga muda |
| [produto/key-recipes.json](produto/key-recipes.json) | Os casos de teste das receitas de chave (entrada → chave) | Para conferir uma chave em caso de dúvida |

**Na execução, quem manda é a instância.** O `GET <api>/v1/schema` descreve o modelo que ela aceita, com as propriedades, os valores e os pares de cada relação. Compare o `modelVersion` com a versão no topo da tabela do `produto/MODELO.md` ("Modelo versão N"). Se forem diferentes, siga o `/v1/schema` e avise a pessoa que a skill está em outra versão (`./install.sh` de novo atualiza).

## Regras

1. **As fontes são só de leitura.** Nenhum comando escreve, commita, instala, aplica ou reinicia algo num repositório, cluster, catálogo ou diretório. Só valem leituras: `git log`, `kubectl get`, `gh api` com GET, `helm get values`. Antes de usar um acesso com credencial (cluster, nuvem, diretório), diga à pessoa o que vai ler e espere o sim.
2. **Nada sem evidência.** Cada fato aponta onde foi visto: `repo@commit:caminho#L42`, a URL do registro, ou o objeto no cluster. Sem evidência, o fato fica de fora e vai para o `LACUNAS.md`.
3. **Nada inventado.** Não deduza dono pelo nome do repositório, versão por convenção nem tópico pelo nome da classe. Placeholder sem valor (`${...}`), caminho montado em execução e tipo genérico sem resolução são lacunas, com o trecho.
4. **A fonte e o escopo do sistema que viu o fato**, iguais aos do adaptador do assunto ([referencias/o-que-importar.md](referencias/o-que-importar.md)). Nunca `manual`, `seed`, `agente` ou o nome desta skill.
5. **As chaves pelas receitas** do modelo. Com o grafo no ar, procure antes se o nó já existe e reaproveite a chave dele (fase 4).
6. **Sem segredos.** Nenhuma senha, token ou string de conexão completa entra num retrato. De um banco, só o servidor e o nome; de uma URL de repositório, nada antes do host.
7. **Retrato completo.** Cada envio substitui o retrato anterior da mesma fonte e escopo, e o que ficou de fora vira `stale`. Um `stale` que ninguém esperava no dry-run quer dizer que falta algo no retrato.
8. **Nada é gravado sem confirmação.** Mostre o dry-run e as lacunas, e só envie quando a pessoa disser que pode.

## Entradas

Pergunte só o que não estiver claro:

- **A API.** O padrão é `http://localhost:3200` (`GRAPH_API_URL`). O token vai em `GRAPH_API_TOKEN` quando a instância exige: veja a fase 1.
- **O que importar.** Pode ser uma lista de assuntos ou "tudo o que der" de um conjunto de fontes: caminhos de repositórios, um cluster, um catálogo, um export.
- **Onde gravar a carga.** O padrão é `./carga-grafo`, fora dos repositórios lidos.

## Saída

```
carga-grafo/
  retratos/<fonte>--<escopo>.json   # um retrato por fonte e escopo, o corpo do POST /v1/ingest
  DESCOBERTA.md                     # cada fato com a evidência e o acesso de onde veio
  LACUNAS.md                        # o que precisa de uma pessoa para confirmar
```

Um retrato só existe se houver de onde tirá-lo. Um retrato vazio diz ao grafo que, naquele escopo, a fonte não vê mais nada. Um retrato ausente diz que a fonte não foi lida. Um exemplo completo, que passa no dry-run, está em [exemplos/carga-grafo/](exemplos/carga-grafo/).

## Fases

### 1. Conhecer a instância

- `GET <api>/v1/schema`: o modelo e a versão (veja [O modelo](#o-modelo)).
- `GET <api>/v1/auth/me`:
  - `mode: anonymous` é uma instância sem login;
  - `mode: sso` exige token em tudo;
  - mesmo no modo anônimo, a escrita pode exigir o token de ingestão.
  
  O dry-run da fase 6 dá `401` se faltar o token. Peça o token à pessoa e use-o só pela variável `GRAPH_API_TOKEN`, sem gravá-lo em arquivo.
- `sources_status` (`POST <api>/v1/queries/sources_status`, ou a ferramenta do MCP `panorama-graph`): as fontes e escopos que já existem, de quem são (`producer`) e de quando é a última carga. Uma fonte publicada por um adaptador fica de fora da carga.

### 2. Combinar o que importar

Faça o inventário do que está ao alcance:

- os repositórios indicados;
- as CLIs instaladas (`command -v git gh glab kubectl helm az aws gcloud`) e se cada uma tem contexto configurado;
- as ferramentas MCP da sessão;
- os arquivos e exports que a pessoa der.

Cruze esse inventário com o catálogo de assuntos em [referencias/o-que-importar.md](referencias/o-que-importar.md). Mostre à pessoa uma tabela com assunto, fonte, escopo, de onde virá e o que falta. Explique também o que não cabe no modelo. Combine o recorte antes de ler qualquer coisa com credencial.

### 3. Descobrir

Siga [referencias/descoberta.md](referencias/descoberta.md), assunto por assunto: onde procurar no código, na configuração e em cada acesso, e o que fazer quando não resolve.

Anote cada fato no `DESCOBERTA.md`, com a evidência e o acesso de onde veio. Para cada repositório, anote também o commit lido e se há mudanças não commitadas. A evidência é do commit, então avise quando houver mudanças fora dele.

Sempre que achar a versão de uma API, de uma operação ou de um tópico, em qualquer padrão, leve-a à carga. O grafo guarda um nó por versão ([produto/MODELO.md](produto/MODELO.md#versões-de-apis-e-tópicos)).

### 4. Reaproveitar o que o grafo já tem

Antes de fechar as chaves, com o grafo no ar:

- **`nodes_find`** (`{ "text": "<nome>" }`) para cada componente, serviço, time, banco e ambiente. Se o nó já existe com outra chave, use a existente.
- **`api_consumers`** (`{ "target": "api:<serviço>/http" }`). Se algum consumidor chama a API por outro nome de serviço, um dos lados está errado. Registre no `LACUNAS.md` e não renomeie o consumidor.
- **`nodes_find`** (`{ "text": "<serviço>", "types": ["Api", "Topic"] }`): as versões que o grafo já conhece. Se os consumidores chamam uma versão que o provedor não tem, procure de novo no provedor. Se não achar, registre a lacuna.

### 5. Montar os retratos

Siga [referencias/retratos.md](referencias/retratos.md): um arquivo por fonte e escopo, com o `observedAt`, a evidência, as chaves e as propriedades do modelo. Para cada relação, confira os pares e o exemplo em [produto/ADAPTADOR.md](produto/ADAPTADOR.md#relações-uma-a-uma).

### 6. Conferir

```sh
<skill>/scripts/enviar.sh --dry-run carga-grafo
```

A API confere cada retrato como numa carga de verdade e não grava nada. Antes, o script confere se a API tem o dry-run. Uma versão antiga ignoraria o parâmetro e gravaria, então nesse caso o script para sem enviar nada, e a API precisa ser atualizada. O dry-run devolve, por retrato, quantos nós e relações seriam criados, alterados, mantidos e tirados (`stale`). Trate assim:

- **`422 invalid_snapshot`:** `details.errors` diz o fato e o motivo (propriedade, valor ou par fora do modelo, ou fato sem evidência). Corrija o retrato ou leve o fato para as lacunas.
- **`409 outdated_snapshot`:** o escopo já tem um retrato mais novo. Ou a fonte é de outro produtor (pare e avise), ou o `observedAt` ficou para trás (use o momento da leitura).
- **`stale` maior que zero:** o retrato atual tem fatos que este não tem. Ou eles sumiram da fonte, ou a leitura ficou incompleta. Descubra qual dos dois antes de seguir.
- **`referenced`:** nós que ninguém declarou ainda. É normal para o que outra fonte vai declarar. Se o nó já existe com outra chave, a chave está errada.

### 7. Enviar, com confirmação

Mostre à pessoa:

- o resumo do dry-run por retrato;
- o `LACUNAS.md`;
- de cada assunto, de onde vieram os fatos.

Só com a confirmação:

```sh
<skill>/scripts/enviar.sh carga-grafo
```

Rode de novo. A segunda vez deve vir só com `unchanged` (`=`), porque a carga é idempotente com o mesmo `observedAt`.

Depois, abra a ficha de um componente no console, ou use `component_get`. Confira dono, sistema, API, consumidores e bancos, cada um com a fonte.

## Relatório final

Diga à pessoa:

- **O que foi importado**, por assunto e por fonte: componentes, APIs e as versões delas, endpoints, tópicos, clientes, bancos, times e ambientes.
- **As lacunas que ficaram** e o que a pessoa precisa decidir.
- **Que esta carga não acompanha as fontes.** Ela é um retrato do que foi lido, e não se atualiza sozinha. Para isso, o caminho é adotar os adaptadores (guia de adoção do panorama-graph). Como a carga usa as mesmas fontes e os mesmos escopos deles, o primeiro envio de cada adaptador a substitui.
