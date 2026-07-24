# Instalador S.I.L. (deploy no cliente)

Automatiza API, firewall, script de subida, APK com IP correto e (opcional) ADB.
Inclui **interface visual** para o cliente acompanhar cada procedimento.

## Uso recomendado no cliente (executavel)

1. Clique duplo em **`SIL-Instalador.exe`** (pede UAC / administrador)
2. Revise IP / nome do cliente na esquerda
3. Clique em **Iniciar instalacao**
4. Acompanhe a lista de procedimentos e o log a direita

> O `.exe` precisa ficar **na pasta `instalador\`**, junto com `Abrir-Instalador.ps1` e `SilEngine.ps1`.

Alternativa: clique direito em `Abrir-Instalador.bat` → **Executar como administrador**.

```text
instalador\
  SIL-Instalador.exe       <-- clique duplo (UAC admin)
  Abrir-Instalador.bat     <-- atalho / fallback
  Abrir-Instalador.ps1     <-- interface WinForms
  Instalar-SIL.ps1         <-- modo texto / automacao CI
  SilEngine.ps1            <-- motor compartilhado
  Build-Exe.ps1            <-- recompila o .exe
  launcher\                <-- fonte C# do launcher
  cliente.exemplo.json
  saida\                   <-- APKs gerados
```

### Recompilar o .exe

```powershell
cd instalador
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Exe.ps1
```

Requer apenas o compilador `csc.exe` do .NET Framework 4.x (ja incluso no Windows).

## O que a tela mostra

| Area | Conteudo |
|------|----------|
| Cabecalho | Identidade S.I.L. |
| Esquerda | Dados do cliente (IP, porta, Flutter, mock/oracle) |
| Direita cima | Checklist ao vivo: `[ ]` pendente, `[>]` em andamento, `[OK]` feito, `[X]` erro |
| Direita baixo | Log detalhado com horario |
| Rodape | Status + barra de progresso |
| Botoes | Iniciar, Simular (Dry-Run), Abrir pasta APK, Carregar JSON |

Antes de gravar qualquer coisa, pede **confirmacao** explicando o que sera feito.

## Modo texto / reexecucao

```powershell
cd instalador
Set-ExecutionPolicy -Scope Process Bypass

# Wizard texto
.\Instalar-SIL.ps1

# Config salva
.\Instalar-SIL.ps1 -Config .\cliente-RHM.json
.\Instalar-SIL.ps1 -Config .\cliente-RHM.json -SomenteApk
.\Instalar-SIL.ps1 -Config .\cliente-RHM.json -DryRun

# Abrir UI direto
.\SIL-Instalador.exe
.\Abrir-Instalador.ps1
.\Instalar-SIL.ps1 -Ui
```

## Passos automatizados (checklist)

1. Verificar / baixar Flutter, JDK e Android SDK  
2. Salvar configuracao do cliente  
3. Instalar dependencias da API  
4. Gerar script `Iniciar-API-<cliente>.ps1`  
5. Liberar firewall  
6. Atalho no logon (opcional)  
7. Iniciar API  
8. Testar `/health`  
9. Compilar APK com `SIL_API_BASE_URL`  
10. Instalar no coletor via ADB (opcional)  
11. Finalizacao  

## Pre-requisitos: o instalador baixa sozinho?

**Sim, com confirmacao.** Antes de instalar, o programa verifica:

| Item | Uso |
|------|-----|
| Flutter/Dart (stable) | API + APK |
| JDK 17 | Compilar APK |
| Android SDK + ADB | Compilar APK / instalar no coletor |

Se algo faltar, aparece um dialogo **Yes/No**. So baixa se o usuario confirmar (pode levar varios GB e minutos).

Na tela visual ha o botao **Verificar** ao lado do campo Flutter para checar (e opcionalmente baixar) sem iniciar o deploy completo.

Pastas padrao dos downloads:
- Ferramentas: `D:\SIL_tools` (ou `C:\SIL_tools` / `%LOCALAPPDATA%\SIL_tools`)
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`

## Se nao abrir / nao funcionar

1. Clique duplo em `SIL-Instalador.exe` e aceite o UAC  
2. Se a janela nao abrir, veja `instalador_erro.txt` na mesma pasta  
3. Teste o motor sem tela:

```powershell
cd instalador
powershell -NoProfile -ExecutionPolicy Bypass -File .\Instalar-SIL.ps1 -Config .\cliente.exemplo.json -DryRun
```

4. Politica de execucao (so na sessao atual):

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

- SQL/Oracle Winthor (`OracleWinthorRepository`)
- Keystore Play Store / politicas MDM avancadas
- Se o IP do servidor mudar: rode de novo (UI ou `-SomenteApk`)
