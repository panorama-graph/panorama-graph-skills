# skills

Skills para agentes de IA (Claude Code, Copilot no VS Code e outros que leem o formato aberto de Agent Skills) que trabalham com o panorama-graph. Cada skill fica numa pasta em [skills/](skills/), com um `SKILL.md` e os arquivos de apoio.

| Skill | O que faz | Requisitos |
|---|---|---|
| [panorama-graph-carga-manual](skills/panorama-graph-carga-manual/SKILL.md) | Alimenta o grafo com a arquitetura real de repositórios que ainda não usam os adaptadores, **sem modificar os projetos**: o agente explora cada repositório, gera o pacote `build/architecture` de cada componente (pelo plugin Gradle aplicado por init script, quando dá, e pela leitura do código no que faltar) e o YAML do `graph-seed` para a organização, valida por dry-run e importa com confirmação | Uma instância do grafo no ar (API e `graph-receiver`), `curl` e `jq`; `docker` com a imagem dos adaptadores (ou `GRAPH_SEED`) para a organização; para projetos Gradle, o plugin publicado num repositório Maven |

A carga manual é para experimentar o grafo. Ela é um retrato do commit lido e não acompanha o código: para isso, adote os adaptadores ([guia de adoção](https://github.com/panorama-graph/panorama-graph/blob/main/ADOCAO.md)). Como usa as mesmas fontes e os mesmos escopos dos adaptadores, o primeiro envio real substitui a carga manual.

## Instalação

```bash
git clone https://github.com/panorama-graph/skills.git && cd skills
./install.sh                          # todas as skills; pergunta para quais formatos
./install.sh --project ~/meu-repo     # no repositório, para o time inteiro
./install.sh --link --claude          # link para esta pasta: um git pull já atualiza a skill
```

| Formato | Diretório | Quem lê |
|---|---|---|
| `claude` | `~/.claude/skills` | Claude Code |
| `agents` | `~/.agents/skills` | Diretório genérico de Agent Skills: Copilot no VS Code e outros agentes |

Com os dois, a skill é copiada para `~/.agents/skills` e `~/.claude/skills/<skill>` vira um link para ela. `./install.sh --help` lista as opções (`--list`, `--uninstall`).

A skill de carga manual usa os schemas dos formatos de build, que são do [repositório dos adaptadores](https://github.com/panorama-graph/adapters/tree/main/schemas): o instalador os baixa (com `curl` e `tar`) para `skills/<skill>/schemas/` e os leva junto na cópia. Por padrão vêm do `main`; `--schemas-ref <tag>` fixa uma versão, e `--schemas-dir <pasta>` copia de uma cópia local dos adaptadores, sem rede. No Windows, rode o instalador pelo Git Bash.

## Uso

Peça ao agente, por exemplo: "carregue no panorama-graph os repositórios em `~/projetos/loja`, sem mexer neles". Ele segue a skill: descobre, gera em `./carga-grafo`, valida, mostra as lacunas e pede confirmação antes de importar. Um exemplo completo da pasta gerada está em [exemplos/carga-grafo/](skills/panorama-graph-carga-manual/exemplos/carga-grafo/).

Para importar uma pasta de carga sem o agente:

```bash
skills/panorama-graph-carga-manual/scripts/importar.sh --dry-run carga-grafo
RECEIVER_URL=http://graph-receiver.interno:3210 GRAPH_API_URL=http://graph-api.interno:3200 \
  skills/panorama-graph-carga-manual/scripts/importar.sh carga-grafo
```
