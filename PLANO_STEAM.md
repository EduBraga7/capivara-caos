# Capivara Caos — Avaliação e Plano de Lançamento na Steam

> Números de mercado abaixo são regras de bolso da comunidade indie, não garantias. Confira taxas e regras atuais no Steamworks antes de decidir.

## 1. Onde o jogo está hoje

**Já tem (muito bom para um projeto solo):**
- Loop completo de survivors-like: 10 min por partida, 3 chefes (Jacaré 3:00, Onça 6:00, Sucuri 10:00), eventos roteirizados, elites, baús e evoluções.
- 8 armas com 8 níveis e evolução (arma + passivo), 12 passivos, 5 personagens, loja de meta-progressão (12 upgrades), 16 conquistas.
- PT/EN, gamepad, opções de acessibilidade (tremor, flashes, números), 3 dificuldades, save em JSON, export Windows/Web.
- Identidade temática forte: capivara + humor brasileiro (Chinelada, Pão de Queijo, Fumacê, Vuvuzela). **Esse é seu maior ativo comercial.**

**Lacunas para vender (por prioridade):**

| # | Lacuna | Por que importa |
|---|--------|-----------------|
| 1 | **Um único mapa/cenário** | Jogadores do gênero esperam variedade. Com 1 mapa, a rejogabilidade acaba em ~5 h. |
| 2 | **Áudio 100% procedural (Python/numpy)** | A música é o que mais denuncia "jogo de protótipo". Troque ao menos as 3 músicas por faixas reais (compositor, banco licenciado ou freelancer). |
| 3 | **Arte vetorial procedural (`art.gd`)** | Tem coerência visual, mas screenshots/trailer precisam de "wow". Capsule art e key art profissionais são obrigatórios. |
| 4 | **Sem integração Steam** | Faltam conquistas Steam, nuvem e overlay. Use GodotSteam (conquistas já existem em `defs.gd`, é só mapear). |
| 5 | **Pouco conteúdo de "descoberta"** | 5 personagens e 8 armas é pouco comparado a concorrentes (Vampire Survivors tem dezenas). Meta: 8+ armas novas, 8 personagens, 3 mapas. |
| 6 | **Build gigante (172 MB exe)** | Provavelmente template de debug/não-otimizado. Exportar em release e comprimir. |
| 7 | **Sem Steam Deck / remap de teclas / resolução** | Steam Deck verificado ajuda muito em visibilidade. |
| 8 | **Poucas "reviravoltas" de sistema** | Falta algo que o diferencie: o gancho "ela só queria relaxar" (regen, lama, spa) deve virar mecânica central, não só tema. |

## 2. Melhorias de jogo (ordem sugerida)

**Antes do demo / Next Fest (essencial):**
1. Tutorial curto (primeiros 60 s sem texto longo) e tela de "build" legível.
2. **2º e 3º mapas** (ex.: Cerrado e Cidade/Feira) com inimigos, hazards e chefes próprios.
3. Música real + mixagem; pelo menos 1 faixa por mapa e 1 de chefe.
4. Polimento de "game feel": hit-stop, screen shake opcional, números de dano, som de coleta encadeado.
5. Balanceamento com dados: use o `bot.gd` para simular builds e achar armas/ passivos quebrados.
6. Telemetria local opcional (taxa de vitória por personagem/arma) para decidir o que ajustar.

**Antes do lançamento 1.0:**
7. Mais 4 armas, 3 personagens (cada um com mecânica própria, não só stat).
8. Modo "Infinito"/Hard com recompensas e mutadores (replay).
9. Conquistas Steam (16 existentes + 8 novas), cartas colecionáveis só depois (exige vendas).
10. Remap de controles, opção de resolução/vsync/FPS, modo daltônico.
11. Localização: PT/EN já existe. Adicione **ES, ZH-CN, RU** (os 3 maiores mercados depois do inglês). Contratar tradução só de UI curta é barato.

**Pós-lançamento (atualizações grátis alimentam wishlist e reviews):**
12. Patch de 1–2 meses depois com novo mapa/personagem; o algoritmo da Steam premia atualizações.

## 3. Cronograma proposto (12–14 semanas)

| Semana | Entregas |
|--------|----------|
| 1–2 | Coletar feedback do itch.io (professores/amigos), consertar bugs e confusões. Decidir escopo. |
| 2–4 | Registrar na Steamworks (US$100 por app), pagar, preencher impostos/banco. Criar página da loja "Coming Soon" **assim que tiver capsule art + 5 screenshots + trailer curto**. |
| 3–8 | Produção: 2 novos mapas, música real, conteúdo novo, integração GodotSteam, Steam Deck. |
| 6 | Página da loja publicada (precisa de revisão da Valve; leva dias) → começa a acumular **wishlists**. |
| 8–10 | **Demo** na Steam (primeiros 5 min ou 1ª partida completa + 1 mapa). Participar de um **Steam Next Fest** (verifique datas no Steamworks; inscrição ~2 meses antes). |
| 10–12 | Beta fechado com 20–50 pessoas (Discord), correções finais, assets de loja finais. |
| 12–14 | Lançamento 1.0 (Early Access é opção, veja seção 5). |

## 4. Marketing (o que realmente move vendas)

**A meta de wishlists:** a regra de bolso é ter 7 000–10 000 wishlists antes do lançamento para ter chance de aparecer em "Popular New Releases". Abaixo de ~2 000 as vendas costumam ser muito baixas. Wishlists vêm de visibilidade, **não da qualidade do jogo sozinha**.

**Táticas, por ordem de custo-benefício:**
1. **Trailer curto (30–45 s) com gameplay nos primeiros 5 s**, texto mínimo, tela final com o logo e "Wishlist now".
2. **GIFs/clipes para TikTok, Shorts e Reels** mostrando momentos engraçados (o humor brasileiro e a capivara são "memeáveis"). Posts diários durante 4–8 semanas.
3. **Demo na Steam** — é o melhor conversor de wishlist de jogos do gênero.
4. **Steam Next Fest** — pode gerar milhares de wishlists.
5. **Streamers/YouTubers brasileiros** de jogos indie e de "survivors-like": enviar chaves Steam (peça via Steamworks, grátis) com um e-mail curto e personalizado. Foque em canais pequenos/médios (1k–100k), taxa de resposta maior.
6. **Comunidades**: r/gamedev (devlog), r/indiegaming, r/PlayMyGame, Discord do Godot, grupos brasileiros de gamedev, Twitter/X e Bluesky. Poste devlogs, não só "comprem".
7. **Brasil**: Brazil Game Show / BIG Festival / Gamescom Latam são vitrines para jogos nacionais; vale aplicar.
8. **itch.io**: mantenha a versão grátis (web) como funil; dentro dela, botão "Wishlist on Steam". Coloque o link em todo lugar (jogo, descrição, Discord).
9. **Press kit** simples (logo, screenshots, GIFs, descrição, contato) em uma página.

**Dica de nome/gancho:** "Ela só queria relaxar" é ótima tagline. Use-a no trailer, na capa e na descrição curta.

## 5. Preço, plataforma e finanças

- **Preço:** US$3,99–4,99 (R$ regionalizado pela Steam). Survivors-likes vendem em 2,99–7,99; o valor percebido depende do conteúdo. Comece em US$4,99 se tiver 3 mapas; US$3,99 se tiver 1–2.
- **Descontos:** 10–20% no lançamento (primeira semana). Evite promoções profundas antes de 6 meses.
- **Early Access?** Funciona bem no gênero (muita base de fãs aceita), mas **só se você puder entregar atualizações regulares**. Prefira lançar 1.0 com conteúdo sólido, ou EA com roadmap claro de 6–9 meses.
- **Taxa Steam:** 30% da receita. Valor de registro US$100 por app (reembolsável após US$1 000 de vendas ajustadas). Verifique no Steamworks.
- **Impostos no Brasil:** como pessoa física, a Steam exige formulário fiscal (W-8BEN) e conta bancária; royalties de fonte estrangeira têm tributação própria. **Consulte um contador** — é frequente abrir MEI/ME para receber como PJ. Faça isso antes de publicar a página.
- **Orçamento mínimo estimado:** US$100 (Steam) + arte de capsule (R$300–1 500) + música (R$500–3 000 ou banco licenciado) + trailer (próprio) + ferramentas = **R$1 500–6 000**. Dá para fazer mais barato com mais trabalho próprio.
- **Expectativa realista:** a maioria dos jogos indie vende pouco; um survivors-like polido e bem divulgado, com ~5–10k wishlists, costuma ficar na faixa de alguns milhares de cópias no primeiro ano. Isso significa **dezenas de milhares de reais**, não milhões. Para maximizar, é preciso (a) volume de wishlists e (b) lançar com conteúdo e polimento muito acima do protótipo.

## 6. Checklist da página da Steam

- [ ] Capsule art (header 460×215, capsule 616×353, 374×448, 231×87, hero 3840×1240, logo) — **sem texto ilegível em tamanho pequeno**
- [ ] 5–8 screenshots com ação, sem UI de debug
- [ ] Trailer (≥1, 30–60 s)
- [ ] Descrição curta (≤300 caracteres) + descrição longa com gifs
- [ ] Tags corretas: *Roguelite, Survivors-like, Bullet Heaven, Action Roguelike, Pixel/Colorful, Funny, Casual, Great Soundtrack* (somente se for verdade), *Brazilian*
- [ ] Idiomas listados (PT-BR, EN; ES/ZH-CN/RU se feitos)
- [ ] Classificação etária e questionário de conteúdo
- [ ] Política de privacidade e e-mail de suporte
- [ ] Build upload via SteamPipe, teste em Steam Deck
- [ ] Ícone do app, capsule “Coming Soon” publicada o mais cedo possível

## 7. Riscos principais

1. **Mercado saturado** de survivors-likes → só compete com identidade forte (humor BR, capivara) e polimento.
2. **Poucos wishlists** → mesmo ótimo, o jogo some. Comece marketing hoje, não no lançamento.
3. **Escopo crescendo** → defina o "mínimo vendável" (3 mapas, 8 personagens, música real) e congele.
4. **Áudio/arte percebidos como amadores** → investir pouco dinheiro aqui tem o maior retorno.
5. **Impostos/conta bancária** atrasando o lançamento → resolver na primeira semana.

## 8. Próximos passos imediatos (esta semana)

1. Publicar no itch.io com um botão/link claro de feedback (formulário Google Forms com 8–10 perguntas: onde morreu, o que não entendeu, qual arma mais gostou, repetiria?, pagaria quanto?).
2. Criar conta Steamworks e começar o cadastro fiscal.
3. Gravar 10 clipes curtos de gameplay engraçado e postar no TikTok/Shorts/X.
4. Montar o servidor do Discord (mesmo pequeno) e linkar na página do itch.
5. Definir o escopo mínimo (seção 2) e transformar em tarefas.
