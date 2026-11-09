# Etiquetas Bling

App Flutter para Windows que busca produtos no Bling e imprime etiquetas de
código de barras (39,8 × 10 mm, 2 colunas) direto na impressora GK888t via
ZPL, enviado em modo RAW pelo spooler do Windows.

## Como rodar (precisa ser no Windows, onde a impressora está ligada)

```
flutter pub get
flutter run -d windows
```

## Configuração inicial

1. No Bling, vá em **Configurações > Aplicativos > Meus Aplicativos** e crie
   um app com:
   - Redirect URI: `http://localhost:17432/callback`
   - Escopo: leitura de produtos
2. Abra o app, vá em **Configurações**, cole o **Client ID** e **Client
   Secret** e salve.
3. Clique em **Entrar no Bling** — abre o navegador para autorizar o app.
4. Em **Configurações**, selecione a impressora GK888t na lista (ela precisa
   estar instalada no Windows, com o driver RAW/genérico, não necessariamente
   o driver de etiqueta — a impressão é feita crua, sem o GDI).
5. Volte para a tela principal e clique no botão de sincronizar (🔄) para
   baixar os produtos para o cache local.

## Uso do dia a dia

1. Busca por nome ou código do produto.
2. Toque no produto para adicionar à fila de impressão (à direita).
3. Ajuste a quantidade de etiquetas de cada item com os botões +/-.
4. Clique em **Imprimir etiquetas**.

## Pontos que precisam de ajuste fino na impressora real

O gerador de ZPL (`lib/services/zpl_label_service.dart`) foi calculado com
base nas medidas informadas (39,8×10mm, 2 colunas, 5mm de gap, 203dpi), mas a
etiqueta é muito pequena (10mm de altura) e provavelmente vai precisar de
ajuste fino depois do primeiro teste real:

- Posição vertical do código de barras e do preço (`barY`, offset do preço).
- Altura do código de barras (`barHeight`) vs. tamanho da fonte do preço.
- Confirme que a GK888t realmente aceita ZPL (não TSPL/EPL). Se não aceitar,
  é só reescrever `_buildRow`/`_buildColumn` na linguagem certa — o resto do
  app (busca, fila, OAuth, cache) não muda.
- O código de barras usa o GTIN como EAN-13 quando o produto tem um GTIN
  válido (12-13 dígitos numéricos); senão cai para o código interno do Bling
  em Code 128.

## Arquitetura

- `lib/services/bling_auth_service.dart` — login OAuth2 (abre o navegador,
  recebe o callback num servidor HTTP local, guarda/renova o token).
- `lib/services/bling_api_service.dart` — busca paginada de produtos na API
  v3 do Bling.
- `lib/services/product_cache.dart` — cache local em SQLite para a busca ser
  instantânea.
- `lib/services/zpl_label_service.dart` — monta o ZPL da etiqueta.
- `lib/services/printer_service.dart` — envia o ZPL direto pro spooler do
  Windows via Win32 API (RAW), usando FFI.
- `lib/screens/home_screen.dart` / `settings_screen.dart` — telas do app.

Tokens e credenciais ficam no Windows Credential Manager via
`flutter_secure_storage`, nunca em texto puro.
