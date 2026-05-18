# Pendências do back-end Laravel (`estudos_api`)

> Documento gerado durante a adequação do Flutter (`estuda_ai_app`) à API
> Laravel existente. **Nada foi alterado no back-end** — esta é uma lista
> de problemas/limitações descobertos, com sugestão técnica, prioridade e
> contrato esperado pelo Flutter.

Convenções usadas abaixo:

- `Authorization: Bearer <token>` (Sanctum) é exigido em todos os endpoints
  marcados como **autenticados**.
- O Flutter espera respostas no padrão "envelope com sucesso" já usado pelo
  resto da API: `{ "success": bool, ... }` quando a chamada é orientada a
  estado (CRUD), e payload "puro" para listagens.

---

## 1. `bootstrap/app.php` retorna **HTTP 200** em `AuthenticationException`

**Severidade:** Alta (impede o Flutter de detectar token expirado de forma
limpa via interceptor padrão do Dio).

Arquivo: `app/../bootstrap/app.php`

```php
$exceptions->render(function (AuthenticationException $e, Request $request) {
    if ($request->expectsJson()) {
        return response()->json([
            'status' => "error",
            'message' => 'Usuário não autenticado',
        ]); // ⚠️ falta o segundo argumento — devolve 200
    }
});
```

### Porquê o Flutter precisa disso

O Flutter (`ApiClient`) trata `401` chamando `onUnauthorized()` (que limpa
token, joga para `/login`). Como o Laravel devolve `200`, foi necessário
adicionar um **fallback** no Flutter detectando o envelope
`{status:"error", message:"Usuário não autenticado"}` em respostas `<400`
e tratando como `401`. É uma adaptação frágil — qualquer mudança de
texto/idioma quebra.

### Sugestão técnica

```php
return response()->json([
    'status'  => 'error',
    'message' => 'Usuário não autenticado',
], 401); // ← status code correto
```

E, idealmente, padronizar para o envelope que o Sanctum/Laravel já usa:
`{message: "Unauthenticated."}`.

**Prioridade:** Alta

---

## 2. `GET /api/buscar-gerar-questoes-tema` não devolve o nome normalizado em todos os casos

**Severidade:** Média (causa uma chamada extra a `listar-temas-user`).

Arquivo: `app/Http/Controllers/TemasController.php` (método
`buscarGerarQuestoesTema`).

### Hoje

| Cenário | Resposta |
| --- | --- |
| Tema já existia + usuário já vinculado | `{success:true, message:"O usuário já está cadastrado no tema $tema"}` |
| Tema já existia + novo vínculo | `{success:true, message:"O usuário foi cadastrado ao tema com sucesso"}` |
| Tema novo gerado | (vem do `armazenaConjuntosTema`) `{success:true, message:"O usuário foi cadastrado ao tema com sucesso"}` |
| Tema inválido | `500` `{success:false, message:"O tema digitado é inválido"}` |

Nos dois casos do meio, o backend **não devolve o nome do tema
normalizado**. O Flutter só consegue descobrir o nome chamando
`listar-temas-user` antes e depois e calculando a diferença.

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

## 3. `UserConclusaoConjunto` não é criado quando o usuário se vincula a um tema **já existente**

**Severidade:** Alta (quebra o fluxo de estudo para usuários que entram em
temas reaproveitados de outros).

Arquivos:

- `app/Http/Controllers/TemasController.php::buscarGerarQuestoesTema` — quando
  o tema já existe, faz `UserTema::create(...)` mas **não cria** registros
  em `user_conclusao_conjunto` para os 7 conjuntos do tema.
- `app/Http/Controllers/TemasController.php::conjuntosTema` — só inclui no
  retorno conjuntos que possuem `UserConclusaoConjunto`:

  ```php
  if($conjuntoConclusao) {
      $conjuntosConclusao[] = [...];
  }
  ```

  Resultado: para esse usuário, `GET /api/listar-conjuntos-tema?tema_id=X`
  devolve **lista vazia**, e `POST /api/concluir-conjunto` retorna `404`
  ("conjunto não encontrado").

### Sugestão técnica

Quando vincular um usuário a um tema existente
(`UserTema::create([...])`), criar também os registros pendentes:

```php
$ids = $buscaTema->conjuntosTema(); // [c1_id, ..., c7_id]
foreach ($ids as $cid) {
    UserConclusaoConjunto::firstOrCreate(
        ['user_id' => $userId, 'conjunto_id' => $cid],
        ['conclusao' => false]
    );
}
```

**Prioridade:** Alta

---

## 4. Falta `GET /api/me` (ou equivalente) para reidratar o usuário logado

**Severidade:** Média.

### Porquê o Flutter precisa disso

Hoje só `POST /api/login` e `POST /api/registrar` devolvem o objeto `user`.
Quando o app é reiniciado com um token válido salvo, o Flutter sabe que o
usuário está autenticado (token existe) mas **não tem nome/e-mail/avatar**
em memória.

Por isso a tela de perfil mostra "Sessão sem dados de perfil (reinicie o
app ou entre de novo)".

### Contrato esperado

```http
GET /api/me
Authorization: Bearer <token>

HTTP 200
{
  "id": 1,
  "name": "Bruno",
  "email": "bruno@example.com",
  "avatar_id": 0,
  "email_verified_at": null
}
```

### Sugestão técnica

```php
Route::middleware('auth:sanctum')->get('/me', function (Request $r) {
    return response()->json($r->user());
});
```

**Prioridade:** Média

---

## 5. Falta endpoint para atualizar perfil (nome, e-mail, avatar)

**Severidade:** Média.

A tabela `users` já tem `name`, `email`, `password`, `avatar_id`, mas só é
possível setar esses campos no `POST /api/registrar`. O Flutter possui a
tela `ProfileSettingsScreen` (com aviso "A API de perfil virá em breve")
que hoje persiste o nome/e-mail **apenas em memória**.

### Contrato esperado

```http
PUT /api/me
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Novo Nome",
  "email": "novo@example.com",
  "avatar_id": 3
}

HTTP 200
{
  "user": {
    "id": 1,
    "name": "Novo Nome",
    "email": "novo@example.com",
    "avatar_id": 3
  }
}

HTTP 422 → { "errors": {...} }   (validação)
HTTP 409 → { "message": "E-mail já em uso" }
```

### Observações

- Senha **deve** ser atualizada por endpoint separado
  (`POST /api/change-password`) exigindo a senha atual — não junto com perfil.
- Validação: `email|unique:users,email,{$user->id}` para não bloquear o
  próprio e-mail.

**Prioridade:** Média

---

## 6. Avatares: persistência por usuário

**Severidade:** Baixa (cosmético; hoje resolvido localmente com
`SharedPreferences`).

### Hoje

- O Flutter tem 10 SVGs em `assets/avatars/` (IDs: `bat`, `bear`, …).
- O `users.avatar_id` é `integer` (default 0) — sem `enum`/lookup.
- Não há endpoint para gravar/ler o `avatar_id`.

### Contrato esperado

Junto do PUT `/api/me` (item 5), aceitar `avatar_id`. Definir convenção:

```
0 — sem avatar (default)
1 — bat, 2 — bear, 3 — bee, 4 — bird, 5 — bunny,
6 — cat, 7 — chicken, 8 — cow, 9 — crocodile, 10 — deer
```

(ou expor `GET /api/avatares` retornando a lista canônica para o Flutter
se basear).

**Prioridade:** Baixa

---

## 7. `POST /api/concluir-conjunto` não desfaz conclusão

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

## 8. Validação de `tema` permite valores que a IA vai rejeitar como `INVALIDO`

**Severidade:** Baixa.

O Flutter usa `min:3` no input. Já existe verificação por IA do lado do
servidor (`Você receberá um texto curto…`), mas qualquer caractere
ruim/curto custa **3 chamadas** caras à OpenAI antes de descobrir.

### Sugestão técnica

No `TemasController::buscarGerarQuestoesTema`, adicionar:

```php
$request->validate([
    "tema" => "required|string|min:3|max:255|regex:/^[\pL\pN\s\-\/.,()]+$/u"
]);
```

E talvez um filtro local rápido (lista de blacklist mínima) antes de
chamar a IA.

**Prioridade:** Baixa

---

## 9. `password_reset_tokens` não tem expiração validada

**Severidade:** Média (segurança).

`PasswordResetController::resetPassword` apenas verifica o hash do token,
não a janela temporal (`created_at`). Token roubado/antigo pode ser
reutilizado indefinidamente.

### Sugestão técnica

```php
$expira = now()->subMinutes(config('auth.passwords.users.expire', 60));
if (Carbon::parse($passwordReset->created_at)->lt($expira)) {
    return response()->json(['message' => 'Token expirado'], 400);
}
```

**Prioridade:** Média

> **Obs:** O Flutter ainda não consome `forgot-password`/`reset-password`
> (não há tela). Quando a tela for criada, este endpoint precisa estar
> seguro.

---

## 10. Tipagem de campos numéricos nas respostas

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
| **Alta** | 1 (auth retorna 200), 3 (sem `UserConclusaoConjunto` no vínculo) |
| **Média** | 2 (sem nome do tema), 4 (`GET /me`), 5 (`PUT /me`), 9 (expiração de token) |
| **Baixa** | 6 (avatar), 7 (desfazer conclusão), 8 (validação `tema`), 10 (tipagem) |

Todos os itens **Alta** e **Média** afetam diretamente a experiência do
usuário Flutter hoje. Os itens **Baixa** são melhorias.
