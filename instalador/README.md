# Instalador S.I.L. (deploy no cliente)

Automatiza API, firewall, script de subida, APK com IP correto e (opcional) ADB.
Inclui **interface visual** para o cliente acompanhar cada procedimento.

## Uso recomendado no cliente (tela visual)

1. Clique com o botao direito em `Abrir-Instalador.bat`
2. **Executar como administrador** (para o firewall)
3. Revise IP / nome do cliente na esquerda
4. Clique em **Iniciar instalacao**
5. Acompanhe a lista de procedimentos e o log a direita

```text
instalador\
  Abrir-Instalador.bat     <-- clique duplo / Executar como Admin
  Abrir-Instalador.ps1     <-- interface WinForms
  Instalar-SIL.ps1         <-- modo texto / automacao CI
  SilEngine.ps1            <-- motor compartilhado
  cliente.exemplo.json
  saida\                   <-- APKs gerados
```

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
.\Abrir-Instalador.ps1
.\Instalar-SIL.ps1 -Ui
```

## Passos automatizados (checklist)

1. Verificar Flutter / Dart  
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

**Nao.** Hoje o instalador **nao baixa** Flutter, Dart, Android SDK nem ADB.

Ele apenas:
- localiza o Flutter/Dart no caminho informado (ou em pastas comuns);
- falha com mensagem clara se nao achar;
- automatiza API, firewall, APK e (opcional) ADB **se** o ambiente ja existir.

Precisa estar no PC do servidor/build **antes**:
| Item | Obrigatorio? |
|------|----------------|
| Flutter (com Dart) | Sim, para API + APK |
| Android SDK / licencas | Sim, para gerar APK |
| ADB | So se marcar "Instalar no coletor" |
| Git | Opcional (se for clonar) |
| Oracle client/driver | So quando `oracle` estiver pronto |

Se quiser, numa proxima entrega dá para acrescentar download automatico do Flutter SDK.

## Se nao abrir / nao funcionar

1. Clique direito em `Abrir-Instalador.bat` → **Executar como administrador**
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
