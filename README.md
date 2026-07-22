# S.I.L. — Sistema Integrado Logístico

MVP Flutter para coletor Android de separação de pedidos Winthor/RHM.

## Executar

```powershell
$env:Path = "D:\flutter\bin;" + $env:Path
flutter pub get
flutter run
```

## Credenciais mock

| Usuário | Senha | Resultado |
| --- | --- | --- |
| `RSGUIMARAES` | `1234` | separador autorizado |
| `JOAOSEP` | `1234` | separador autorizado |
| `MCOMPRAS` | `1234` | bloqueado (`TIPOVENDA = C`) |

O botão de conexão no drawer alterna o modo online/offline para demonstração.
Login, lista, reserva/download e finalização exigem conexão; a bipagem do pedido reservado é persistida em SQLite e funciona offline.

Para a API real, substituir os mocks no repositório pelos endpoints autenticados da API corporativa; o aplicativo não deve conectar diretamente ao Oracle.
