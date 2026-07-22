# S.I.L. — Sistema Integrado Logístico

MVP Flutter para coletor Android de separação de pedidos Winthor/RHM,
mais API intermediária em Dart (`api/`).

## Arquitetura

```
Coletor Flutter  →  API S.I.L. (api/)  →  IWinthorRepository  →  Oracle Winthor
                         ↑                        ↑
                    você mantém            quem conecta o ERP
```

O aplicativo **não** conecta ao Oracle. Consome a API autenticada.
Quem encomendou o sistema preenche `OracleWinthorRepository` com o SQL/procedures.

## App (Flutter)

```powershell
$env:Path = "D:\flutter\bin;" + $env:Path
flutter pub get
flutter run
```

Por padrão o app aponta para `http://10.0.2.2:8080` (API no host vista pelo emulador Android).

```powershell
# API na máquina (outro terminal)
cd api
dart run bin/server.dart

# Coletor apontando para a API (emulador)
flutter run

# Dispositivo físico na mesma rede
flutter run --dart-define=SIL_API_BASE_URL=http://192.168.0.10:8080

# Forçar mocks locais (sem API)
flutter run --dart-define=SIL_API_USE_MOCK=true
```

### Credenciais (API mock / app mock)

| Usuário | Senha | Resultado |
| --- | --- | --- |
| `RSGUIMARAES` | `1234` | separador autorizado |
| `JOAOSEP` | `1234` | separador autorizado |
| `MCOMPRAS` | `1234` | bloqueado (`TIPOVENDA = C`) |

O botão de conexão no drawer alterna o modo online/offline para demonstração.
Login, lista, reserva/download e finalização exigem conexão; a bipagem do pedido reservado é persistida em SQLite e funciona offline.

`SessionService` e `PedidosRepository` chamam a API (`/auth/login`, `/pedidos`, reservar, finalizar). Com `SIL_API_USE_MOCK=true` voltam aos dados locais.

## Testes automatizados

```powershell
$env:Path = "D:\flutter\bin;" + $env:Path

# App: mocks de prioridade + cliente HTTP + integração contra API real em memória
flutter test

# API isolada
cd api
dart test
```

Os testes em `test/integration_api_test.dart` sobem a API Shelf em porta efêmera e exercitam o mesmo `SilApiClient` do coletor (login → listar → reservar → finalizar), sem emulador.

## API

Ver [`api/README.md`](api/README.md) e o contrato [`api/openapi.yaml`](api/openapi.yaml).

```powershell
$env:Path = "D:\flutter\bin;" + $env:Path
cd api
dart pub get
dart run bin/server.dart
```
