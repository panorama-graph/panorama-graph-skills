# Lacunas

O que a carga não afirma por falta de evidência. Cada item diz o que foi visto e o que falta para resolver.

| Assunto | O quê | Visto | Para resolver |
|---|---|---|---|
| Catálogo | Dono do `orders-api` | `CODEOWNERS` lista só `@ana.souza`, uma pessoa | Qual time é o dono? Entra como `OWNED_BY` no retrato de `service-catalog` |
| Bibliotecas | O SBOM do `orders-api` | — | Autorizar o CycloneDX (`mvn org.cyclonedx:cyclonedx-maven-plugin:makeBom`, com a saída fora do repositório) |
| API | `GET /orders/export` | `ReportController.java#L18`: caminho montado com `"/orders/" + formato` | Confirmar se o caminho é `/orders/{formato}` |
| Eventos | Tópico em produção | `application-prd.yml` sobrescreve `app.topics.order-placed` com `${ORDER_TOPIC}` | O grafo guarda o endereço da configuração padrão; o de produção vem da variável no deploy |
| Implantação | O que roda em cada ambiente | Sem acesso ao cluster | Um contexto do `kubectl` só de leitura, ou adotar o `graph-deployments` |
