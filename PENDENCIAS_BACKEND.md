# Pendências do back-end Laravel (`estudos_api`)

> Documento gerado durante a adequação do Flutter (`estuda_ai_app`) à API
> Laravel existente. Lista de problemas/limitações descobertos, com sugestão
> técnica, prioridade e contrato esperado pelo Flutter.

Convenções usadas abaixo:

- `Authorization: Bearer <token>` (Sanctum) é exigido em todos os endpoints
  marcados como **autenticados**.
- O Flutter espera respostas no padrão "envelope com sucesso" já usado pelo
  resto da API: `{ "success": bool, ... }` quando a chamada é orientada a
  estado (CRUD), e payload "puro" para listagens.

---

## 1. `GET /api/buscar-gerar-questoes-tema` não devolve o nome normalizado em todos os casos

**Severidade:** Média (causa uma chamada extra a `listar-temas-user`).

Arquivos: `app/Http/Controllers/TemasController.php` (`buscarGerarQuestoesTema`)
e `app/Http/Controllers/QuestoesController.php` (`armazenaConjuntosTema`).

### Hoje

| Cenário | Resposta |
| --- | --- |
| Tema já existia + usuário já vinculado | `{success:true, message:"O usuário já está cadastrado no tema $tema"}` |
| Tema já existia + novo vínculo | `{success:true, message:"O usuário foi cadastrado ao tema $tema com sucesso"}` |
| Tema novo gerado | `{success:true, message:"O usuário foi cadastrado ao tema $tema com sucesso"}` |
| Tema inválido | `500` `{success:false, message:"O tema digitado é inválido"}` |

Nos três casos de sucesso, o backend **não devolve o objeto `tema`** (`id` +
`nome`). O Flutter só consegue descobrir o nome chamando `listar-temas-user`
antes e depois e calculando a diferença (ou extraindo da mensagem quando possível).

### Contrato esperado

```json
HTTP 200
{
  "success": true,
  "message": "Tema vinculado ao usuário.",
  "tema": {
    "id": 17,
    "nome": "FOTOSSÍNTESE"
  }
}
```

### Sugestão técnica

Sempre incluir `tema_id` e `tema_nome` (ou um objeto `tema`) na resposta de
sucesso, independentemente do caminho percorrido (já existia, vinculação
nova, geração nova).

**Prioridade:** Média

---

## 2. Falta endpoint para atualizar e-mail

**Severidade:** Baixa (cosmético; o Flutter exibe o e-mail como somente leitura).

A atualização de **nome** e **avatar** já está disponível via endpoints
separados (ver itens resolvidos). Ainda não há rota para alterar o e-mail
do usuário autenticado.

### Contrato sugerido

```http
POST /api/update-email-user
Authorization: Bearer <token>
Content-Type: application/json

{
  "email": "novo@example.com"
}

HTTP 200
{
  "success": true,
  "message": "E-mail atualizado com sucesso",
  "user": {
    "id": 1,
    "name": "Bruno",
    "email": "novo@example.com",
    "avatar_id": 3
  }
}

HTTP 422 → { "errors": {...} }   (validação)
HTTP 409 → { "message": "E-mail já em uso" }
```

### Observações

- Validação: `email|unique:users,email,{$user->id}` para não bloquear o
  próprio e-mail.
- Senha **deve** continuar em endpoint separado (`POST /api/change-password`).

**Prioridade:** Baixa

---

## 3. `POST /api/concluir-conjunto` não desfaz conclusão

**Severidade:** Baixa.

O backend só seta `conclusao = true`. Não há endpoint para reabrir
("desfazer conclusão"). O Flutter atualmente não precisa, mas é útil para
o usuário refazer um conjunto sem ele aparecer como já concluído na home.

### Sugestão técnica

Adicionar `POST /api/reabrir-conjunto` ou aceitar `conclusao: bool` no
endpoint atual:

```json
{ "conjunto_id": 12, "conclusao": false }
```

**Prioridade:** Baixa

---

## 4. Tipagem de campos numéricos nas respostas

**Severidade:** Baixa.

Em `temasUser`, `porcentagem_conclusao` pode ser `null` (quando
`empty($conjuntos)`). O Flutter já trata, mas a documentação OpenAPI/Swagger
deveria refletir.

Em `conjuntosTema`, `conclusao` vem como booleano nativo (`true`/`false`).

Sugestão: padronizar tipos (sempre `int` 0–100 e `bool`) e documentar.

**Prioridade:** Baixa

---

## Resumo por prioridade

| Prioridade | Itens |
| --- | --- |
| **Média** | 1 (sem nome do tema na resposta) |
| **Baixa** | 2 (e-mail), 3 (desfazer conclusão), 4 (tipagem) |

O item **Média** afeta diretamente a experiência do usuário Flutter
(chamada extra a `listar-temas-user` após gerar tema). Os demais são
melhorias.

---

## Itens resolvidos (removidos da lista)

| Item original | Resolução verificada |
| --- | --- |
| 1 — `AuthenticationException` retornava HTTP 200 | `bootstrap/app.php` devolve `401` |
| 3 — `UserConclusaoConjunto` ausente ao vincular tema existente | `TemasController::buscarGerarQuestoesTema` cria registros para os 7 conjuntos |
| 8 — Validação de `tema` insuficiente | Validação `min:3\|max:255\|regex` em `buscarGerarQuestoesTema` |
| 9 — Token de reset sem expiração | `PasswordResetController::resetPassword` valida `created_at` (20 min) |
| 11 — `php artisan serve` single-threaded | `.env` com `PHP_CLI_SERVER_WORKERS=4`; `compose.yaml` (Laravel Sail) disponível para concorrência nativa |
| 3 (doc) — `GET /api/me` com rota quebrada | `routes/api.php` aponta para `UserController::userInfo` |
| 2 (parcial) — atualizar nome de perfil | `POST /api/update-name-user` body `{name}` |
| 4 (doc) — avatar persistido por usuário | `POST /api/update-avatar-user` body `{avatar}` (0–10); `GET /api/me` devolve `avatar_id` |

> **Nota:** a geração assíncrona via Queue (solução definitiva para temas
> longos em produção) ainda não foi implementada, mas o bloqueio total da
> API em desenvolvimento foi mitigado com workers paralelos.
