# S.I.L. API

API intermediária entre o coletor Flutter e o ERP Winthor.

```
Coletor Flutter  →  esta API  →  IWinthorRepository  →  Oracle (quem conecta o ERP)
```

O app **não** acessa o Oracle. Quem encomendou o sistema implementa
`OracleWinthorRepository` (ou troca o provedor) e configura as variáveis Oracle.

## Executar

```powershell
$env:Path = "D:\flutter\bin;" + $env:Path
cd api
dart pub get
dart run bin/server.dart
```

Health: `GET http://localhost:8080/health`

## Endpoints

| Método | Rota | Auth | Descrição |
|--------|------|------|-----------|
| GET | `/health` | — | Status + provedor Winthor |
| POST | `/auth/login` | — | Login do separador |
| GET | `/pedidos` | Bearer | Lista fila de separação |
| POST | `/pedidos/{id}/reservar` | Bearer | Reserva + payload completo |
| POST | `/pedidos/{id}/finalizar` | Bearer | Fecha separação no ERP |

Contrato completo: [`openapi.yaml`](openapi.yaml).

### Exemplos

```powershell
# Login
Invoke-RestMethod -Method Post -Uri http://localhost:8080/auth/login `
  -ContentType application/json `
  -Body '{"usuario":"RSGUIMARAES","senha":"1234"}'

# Lista (substitua TOKEN)
Invoke-RestMethod -Uri http://localhost:8080/pedidos `
  -Headers @{ Authorization = "Bearer TOKEN" }
```

Credenciais mock (iguais ao app):

| Usuário | Senha | Resultado |
|---------|-------|-----------|
| `RSGUIMARAES` | `1234` | OK |
| `JOAOSEP` | `1234` | OK |
| `MCOMPRAS` | `1234` | 403 (não-separador) |

## Conectar o Winthor

1. Implemente os métodos de `lib/src/winthor/oracle_winthor_repository.dart`
   (SQL em `PCEMPR`, `PCPEDC`, etc.).
2. Suba a API com:

```powershell
$env:SIL_WINTHOR_PROVIDER = "oracle"
$env:SIL_ORACLE_CONN = "host:1521/SERVICE"
$env:SIL_ORACLE_USER = "usuario"
$env:SIL_ORACLE_PASSWORD = "senha"
dart run bin/server.dart
```

Enquanto `SIL_WINTHOR_PROVIDER` for `mock` (padrão), a API usa dados em memória.

## Variáveis de ambiente

| Variável | Padrão | Uso |
|----------|--------|-----|
| `SIL_API_HOST` | `0.0.0.0` | Bind |
| `SIL_API_PORT` | `8080` | Porta |
| `SIL_WINTHOR_PROVIDER` | `mock` | `mock` ou `oracle` |
| `SIL_ORACLE_CONN` | — | Connection string Oracle |
| `SIL_ORACLE_USER` | — | Usuário Oracle |
| `SIL_ORACLE_PASSWORD` | — | Senha Oracle |

## Testes

```powershell
dart test
```
