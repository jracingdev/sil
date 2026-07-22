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

### Credenciais mock

| Usuário | Senha | Resultado |
| --- | --- | --- |
| `RSGUIMARAES` | `1234` | separador autorizado |
| `JOAOSEP` | `1234` | separador autorizado |
| `MCOMPRAS` | `1234` | bloqueado (`TIPOVENDA = C`) |

O botão de conexão no drawer alterna o modo online/offline para demonstração.
Login, lista, reserva/download e finalização exigem conexão; a bipagem do pedido reservado é persistida em SQLite e funciona offline.

Hoje o app ainda usa mocks locais em `lib/data/`. O próximo passo de integração é apontar `SessionService` / `PedidosRepository` para a API (`http://host:8080`).

## API

Ver [`api/README.md`](api/README.md) e o contrato [`api/openapi.yaml`](api/openapi.yaml).

```powershell
$env:Path = "D:\flutter\bin;" + $env:Path
cd api
dart pub get
dart run bin/server.dart
```
