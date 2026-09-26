# Painel Gerencial de Obras — Paysage Corpal

Aplicativo web responsivo para gestão de obras, hospedado no GitHub Pages e com dados no Supabase.

## Estrutura
- `index.html`: aplicativo completo.
- `schema.sql`: banco, autenticação, RLS, histórico e Realtime.
- `.github/workflows/pages.yml`: publicação automática no GitHub Pages.

## Status
Ações e Acompanhamento OBRA usam exclusivamente:
- Pendente
- Em andamento
- Concluída

## 1. Criar o Supabase
1. Crie um projeto em https://supabase.com/
2. Abra SQL Editor.
3. Execute todo o conteúdo de `schema.sql`.
4. Em Authentication, crie os usuários autorizados (e-mail/senha).
5. Após o primeiro usuário, torne-o admin no SQL:
   `update public.profiles set role='admin' where email='seu.email@empresa.com';`
6. No Project Connect, copie a Project URL e a Publishable key.

## 2. Configurar o aplicativo
No `index.html`, substitua:
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Nunca coloque a Secret key/service_role no HTML.

## 3. GitHub
Crie um repositório e envie:
- `index.html`
- `.github/workflows/pages.yml`
- `README.md`
- `schema.sql` (pode ficar no repositório, mas não é necessário para execução)

Depois, em Settings > Pages, use GitHub Actions como fonte. O workflow fará o deploy a cada push na `main`.

## 4. Relatórios PDF
O botão de relatório solicita/usa o mês selecionado e gera o PDF diretamente no navegador com jsPDF. Não depende de popup nem de impressão do navegador.

## 5. Realtime
O aplicativo assina alterações nas tabelas `works`, `actions` e `accompaniments`. Alterações feitas por usuários autenticados são refletidas nos demais dispositivos.

## 6. Permissões
- `viewer`: consulta.
- `editor`: cria e edita obras, ações e acompanhamentos.
- `admin`: tudo que editor faz + exclusão e gestão de perfis.

O controle real de acesso é feito no banco por RLS; o bloqueio na interface é apenas complementar.
