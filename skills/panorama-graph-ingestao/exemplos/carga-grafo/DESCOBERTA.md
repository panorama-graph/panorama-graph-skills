# Descoberta

Leitura de 23/10/2026, às 12:00 (o `observedAt` de todos os retratos).

## shop/orders-api

Repositório `shop/orders-api` em `git.example.com`, commit `3f2c9e1a7b5d4c3e2f1a0b9c8d7e6f5a4b3c2d1e`, sem mudanças locais. Projeto Maven, versão 1.4.0. Nome de serviço `orders-api` (`src/main/resources/application.yml#L2`, `spring.application.name`).

| Retrato | Acesso | De onde |
|---|---|---|
| `build-manifest` | Repositório local | `pom.xml` (artefato, Java 21, Spring Boot 3.4.8, `scm`), `.mvn/wrapper/maven-wrapper.properties` (Maven 3.9.9), `git remote` e `git rev-parse` |
| `openapi` | Repositório local | `OrderController` (2 operações), com os DTOs `PlaceOrder`, `Order` e `OrderItem` e os erros do `ApiExceptionHandler` no `contract` de cada endpoint. Sem documento OpenAPI no repositório: sem `Contract` |
| `asyncapi` | Repositório local | `OrderEvents.java#L27` (`KafkaTemplate.send`) e `PaymentListener.java` (`@KafkaListener`); os nomes dos tópicos resolvidos em `application.yml#L21-L22` |
| `http-clients` | Repositório local | `CatalogClient` (`@FeignClient(name = "catalog-api-v1")`) |
| `data-access` | Repositório local | `OrderEntity` (`@Entity`, `@Table(name = "orders")`), `OrderRepository` usado em `OrderService` |
| `service-catalog` | Repositório local | `catalog-info.yaml` (domínio, sistema e descrição) |
| `k8s-infra` | Repositório local | `deploy/values-dev.yaml` (o PostgreSQL e o Kafka de dev) |
| `service-config` | Repositório local | `deploy/values-dev.yaml`: `SPRING_DATASOURCE_URL` (servidor e banco, sem credencial) e `KAFKA_BOOTSTRAP_SERVERS` |

Versões: a API do `orders-api` não é versionada (nenhum caminho, anotação ou manifesto traz versão), e os tópicos também não. O catálogo é chamado na v1, pelo host `catalog-api-v1` do `@FeignClient`: o cliente consome `api:catalog-api/v1/http` e chama os endpoints do código do catálogo, sem versão.

Ficaram de fora: `/actuator/**`; o `GET /orders/export`, com caminho montado em execução (lacuna).

Sem acesso ao cluster (`kubectl` sem contexto): nada de `k8s-deployments` nem de `k8s-routes`.
