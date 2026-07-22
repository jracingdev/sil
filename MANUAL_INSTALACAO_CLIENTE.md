# Manual de instalação — S.I.L. (cliente)

**S.I.L. — Sistema Integrado Logístico**  
Coletor Android de separação de pedidos + API intermediária para o ERP Winthor (RHM).

Este documento descreve como instalar e colocar o sistema em operação no ambiente do cliente.

---

## 1. O que será instalado

| Componente | Onde roda | Função |
|------------|-----------|--------|
| **API S.I.L.** | Servidor Windows/Linux na rede local (ou VM) | Autenticação, lista de pedidos, reserva e finalização |
| **App coletor** | Aparelhos Android (coletor industrial ou smartphone) | Login, bipagem, separação offline, finalizar online |
| **Conexão Oracle/Winthor** | Dentro da API (implementação do cliente) | Leitura/escrita nas tabelas do ERP |

```
[Coletor Android]  --HTTP-->  [API S.I.L. :8080]  --SQL-->  [Oracle Winthor]
```

O aplicativo **não** conecta direto no Oracle. Toda comunicação com o ERP passa pela API.

---

## 2. Divisão de responsabilidades

| Parte | Responsável |
|-------|-------------|
| Código do app Flutter e da API | Fornecedor do S.I.L. |
| Servidor, rede, firewall, IP fixo da API | TI do cliente |
| Instalação do APK nos coletores | TI / logística do cliente (com apoio deste manual) |
| Implementar SQL/procedures Winthor em `OracleWinthorRepository` | **Cliente** (quem encomendou / equipe Winthor) |
| Credenciais Oracle, liberação de usuários separadores | TI / ERP do cliente |

---

## 3. Pré-requisitos

### 3.1 Servidor da API

- Windows Server ou Windows 10/11, ou Linux
- Acesso à rede Wi‑Fi/LAN usada pelos coletores
- Porta **TCP 8080** livre (ou outra combinada)
- **Dart SDK 3.12+** **ou** Flutter SDK (inclui o Dart) instalado  
  Exemplo Windows: `D:\flutter\bin` no `PATH`
- Git (opcional, para clonar o repositório)
- Se for usar Winthor de verdade: cliente Oracle / driver conforme a implementação do cliente

### 3.2 Rede

- Coletores e servidor da API na **mesma rede** (ou VPN com rota)
- IP do servidor **conhecido e preferencialmente fixo** (ex.: `192.168.0.50`)
- Firewall do Windows permitindo entrada na porta da API (ex.: 8080)

### 3.3 Coletores Android

- Android compatível com o `minSdk` do app (Flutter atual)
- Wi‑Fi estável no armazém
- Opção de instalar APK (fontes desconhecidas / MDM)
- Câmera **ou** leitor de código de barras (wedge/teclado ou laser nativo em coletores industriais)
- Biometria opcional (digital/Face) se for usar “Entrar com biometria”

### 3.4 Repositório

```
https://github.com/jracingdev/sil.git
```

---

## 4. Instalação da API (servidor)

### 4.1 Obter o código

```powershell
cd C:\apps
git clone https://github.com/jracingdev/sil.git
cd sil
```

Ou copie a pasta do projeto já entregue para o servidor.

### 4.2 Dependências da API

```powershell
$env:Path = "D:\flutter\bin;" + $env:Path   # ajuste o caminho do Flutter/Dart
cd api
dart pub get
```

### 4.3 Teste rápido (modo mock — sem Oracle)

Útil para validar rede e app **antes** da conexão Winthor.

```powershell
cd api
dart run bin/server.dart
```

Deve aparecer algo como:

```text
S.I.L. API em http://0.0.0.0:8080 (winthor=mock)
```

No próprio servidor, teste:

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
```

Resposta esperada:

```json
{ "status": "ok", "winthor": "mock" }
```

De outro PC ou do celular (mesma rede), teste com o IP do servidor:

```text
http://192.168.0.50:8080/health
```

Substitua `192.168.0.50` pelo IP real.

### 4.4 Liberar firewall (Windows)

Execute **como Administrador**:

```powershell
netsh advfirewall firewall add rule name="S.I.L. API 8080" dir=in action=allow protocol=TCP localport=8080
```

### 4.5 Subir a API de forma permanente (sugestão)

Opções comuns:

1. **Atalho / script** na inicialização do Windows  
2. **Serviço NSSM / WinSW** apontando para `dart run bin/server.dart` no diretório `api`  
3. Agendador de Tarefas (ao logon do servidor)

Script exemplo `iniciar_api.ps1`:

```powershell
$env:Path = "D:\flutter\bin;" + $env:Path
$env:SIL_API_HOST = "0.0.0.0"
$env:SIL_API_PORT = "8080"
# Até o Winthor estar pronto, deixe mock:
$env:SIL_WINTHOR_PROVIDER = "mock"
Set-Location "C:\apps\sil\api"
dart run bin/server.dart
```

### 4.6 Variáveis de ambiente da API

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `SIL_API_HOST` | `0.0.0.0` | Escuta em todas as interfaces (necessário para os coletores) |
| `SIL_API_PORT` | `8080` | Porta HTTP |
| `SIL_WINTHOR_PROVIDER` | `mock` | `mock` = dados de demonstração; `oracle` = ERP real |
| `SIL_ORACLE_CONN` | — | Connection string Oracle (quando `oracle`) |
| `SIL_ORACLE_USER` | — | Usuário Oracle |
| `SIL_ORACLE_PASSWORD` | — | Senha Oracle |

---

## 5. Conexão com o Winthor (cliente)

Enquanto `SIL_WINTHOR_PROVIDER=mock`, o sistema funciona com pedidos e usuários de demonstração.

Para produção:

1. Implementar os métodos em:

   `api/lib/src/winthor/oracle_winthor_repository.dart`

   Contrato: `api/lib/src/winthor/winthor_repository.dart`  
   OpenAPI: `api/openapi.yaml`

2. Operações esperadas:

   | Método | Objetivo típico no Winthor |
   |--------|----------------------------|
   | `autenticar` | Validar usuário; rejeitar não-separador (ex. `TIPOVENDA = C`); filial via `PCEMPR` |
   | `listarPedidos` | Fila de separação + itens + endereço M-R-P-A |
   | `reservarPedido` | Reserva atômica + payload completo |
   | `finalizarPedido` | Ex.: `UPDATE PCPEDC SET DTFINALSEP1 = SYSDATE` |

3. Subir a API com:

```powershell
$env:SIL_WINTHOR_PROVIDER = "oracle"
$env:SIL_ORACLE_CONN = "host:1521/SERVICE"
$env:SIL_ORACLE_USER = "usuario"
$env:SIL_ORACLE_PASSWORD = "senha"
dart run bin/server.dart
```

`GET /health` deve retornar `"winthor": "oracle"`.

---

## 6. Gerar e instalar o aplicativo (coletores)

### 6.1 Máquina de build

- Flutter SDK instalado (`flutter doctor` ok)
- Android SDK / aceitar licenças
- Clone do mesmo repositório `sil`

### 6.2 Descobrir o IP da API

No servidor:

```powershell
ipconfig
```

Anote o IPv4 da placa ligada à rede dos coletores (ex.: `192.168.0.50`).

### 6.3 Gerar o APK apontando para a API do cliente

**Importante:** a URL da API é gravada no APK na compilação (`--dart-define`).  
Se o IP do servidor mudar, é preciso **gerar de novo** o APK.

```powershell
$env:Path = "D:\flutter\bin;" + $env:Path
cd C:\apps\sil

# Troque pelo IP real do servidor da API no cliente:
flutter build apk --release --dart-define=SIL_API_BASE_URL=http://192.168.0.50:8080
```

APK gerado em:

```text
build\app\outputs\flutter-apk\app-release.apk
```

> **Observação:** o build release atual ainda usa assinatura debug de desenvolvimento. Para Play Store / política corporativa rígida, configure um keystore de release (equipe de desenvolvimento).

### 6.4 Instalar no coletor

**Opção A — cabo USB + ADB**

1. Ative *Depuração USB* / *Depuração sem fio* no aparelho  
2. Conecte o coletor ao PC de build  

```powershell
adb devices
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

**Opção B — arquivo**

1. Copie `app-release.apk` para o aparelho (pendrive, pasta compartilhada, MDM)  
2. No Android, permita instalar apps de fonte desconhecida (ou publique via MDM)  
3. Abra o APK e confirme a instalação  

**Opção C — MDM / EMM**

Publique o APK no gerenciador de dispositivos da empresa e faça o push para o grupo “Separação”.

### 6.5 Pacote do aplicativo

- **ID:** `br.com.rhm.rhm_coletor`  
- **Nome na tela:** S.I.L. — Sistema Integrado Logístico  

---

## 7. Primeiro uso no coletor

1. Coletor na **mesma Wi‑Fi** do servidor da API  
2. Abra o S.I.L.  
3. (Opcional) Marque **Lembrar-me** e **Usar biometria**  
4. Login (modo mock):

   | Usuário | Senha | Resultado |
   |---------|-------|-----------|
   | `RSGUIMARAES` | `1234` | Separador OK |
   | `JOAOSEP` | `1234` | Separador OK |
   | `MCOMPRAS` | `1234` | Bloqueado (não-separador) |

   Em produção, use os usuários Winthor liberados pela TI.

5. Confirme a **filial**  
6. Menu → **Separação de Pedido**  
7. Selecione um pedido → informe **número da comanda** (qualquer valor não vazio no mock)  
8. Bipar endereço (`M-R-P-A`) e produtos (`codauxiliar` ou `codfab`)  
9. **Finalizar** com o coletor **online** (pedido some da lista após sucesso na API)

### 7.1 Sons de confirmação

| Evento | Som |
|--------|-----|
| Endereço válido | Beep médio |
| Produto válido | Beep agudo |
| Finalização OK | Três notas |
| Erro de bip | Alerta do sistema |

### 7.2 Online × offline

| Operação | Rede |
|----------|------|
| Login, lista, reserva, finalizar | **Obrigatória** |
| Bipagem do pedido já reservado | Pode ser **offline** (dados no SQLite) |

---

## 8. Checklist de aceite (cliente)

- [ ] API responde `GET http://<IP>:8080/health` a partir de outro equipamento  
- [ ] Firewall libera a porta da API  
- [ ] APK instalado nos coletores com `SIL_API_BASE_URL` correto  
- [ ] Login de separador funciona  
- [ ] Lista de pedidos aparece  
- [ ] Reserva com comanda funciona  
- [ ] Bipagem de endereço e produto com beep  
- [ ] Finalizar remove o pedido da lista  
- [ ] (Produção) `SIL_WINTHOR_PROVIDER=oracle` e testes com dados reais do ERP  

---

## 9. Problemas frequentes

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| “Sem conexão com a API” | IP errado no APK, API parada, Wi‑Fi diferente, firewall | Conferir IP, `health`, firewall, mesma rede |
| “Token ausente ou inválido” | API reiniciada após o login (sessão só em memória) | Sair do app e logar de novo |
| Lista vazia | Todos reservados/finalizados (mock) ou filtro ERP | Reiniciar API mock ou verificar fila Winthor |
| APK não instala | Fonte desconhecida / versão antiga | Permitir instalação; desinstalar versão anterior |
| Biometria não aparece | Aparelho sem biometria ou “Lembrar-me” desligado | Ativar biometria no Android e marcar as duas opções no login |
| Build falha em pasta com espaço no caminho | Limitação do Gradle em alguns PCs | Compilar a partir de junction sem espaço (ex. `D:\sil_build`) |

---

## 10. Atualização de versão

1. Atualizar código (`git pull` ou pacote novo)  
2. `cd api` → `dart pub get` → reiniciar o serviço da API  
3. Regenerar APK com o **mesmo** (ou novo) `SIL_API_BASE_URL`  
4. `adb install -r app-release.apk` ou republicar no MDM  

---

## 11. Contatos e documentação técnica

| Item | Local |
|------|--------|
| Repositório | https://github.com/jracingdev/sil |
| README geral | `README.md` |
| API | `api/README.md` |
| Contrato HTTP | `api/openapi.yaml` |
| Stub Winthor | `api/lib/src/winthor/oracle_winthor_repository.dart` |

---

## 12. Resumo rápido (produção)

```text
1. Servidor: instalar Dart/Flutter, clonar sil, dart pub get na pasta api
2. Liberar porta 8080 no firewall; IP fixo
3. Cliente implementa OracleWinthorRepository e sobe com SIL_WINTHOR_PROVIDER=oracle
4. Build: flutter build apk --release --dart-define=SIL_API_BASE_URL=http://IP:8080
5. Instalar APK nos coletores
6. Validar health → login → separar → finalizar
```

*Documento alinhado à versão do repositório S.I.L. com API intermediária, bipagem offline, beeps, Lembrar-me e biometria.*
